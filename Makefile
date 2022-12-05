# Needed to use variables in prereqs, such as for the `contexts` target
.SECONDEXPANSION:

# Directories to copy files from (general make feature, not specific to this file)
VPATH = conf vendor volumes/jenkins/war


DOCKER_COMPOSE = docker compose
# Which profiles come up and down automatically with make up, make stop, etc.
AUTO_PROFILES = --profile endpoints --profile core


# List of tomcat contexts, to be given the stock tomcat prereqs
TOMCATS = \
	accessmgmt \
	admincommon \
	appnav \
	bcm \
	eeamc \
	employee \
	extz \
	financess \
	general_ss \
	integrationapi \
	studentapi \

# List of stock tomcat prereqs, given to every tomcat context
TOMCAT_PREREQS = \
	context.xml \
	footer.groovy \
	ojdbc8.jar \
	server.xml \
	setenv.sh \

CONTEXTS_WAR_PREREQS = \
	contexts/accessmgmt/BannerAccessMgmt.war \
	contexts/accessmgmt/BannerAccessMgmt.ws.war \
	contexts/admincommon/BannerAdmin.war \
	contexts/admincommon/BannerAdmin.ws.war \
	contexts/eeamc/ethosapimanagementcenter.war \
	contexts/appnav/applicationNavigator.war \
	contexts/bcm/CommunicationManagement.war \
	contexts/employee/EmployeeSelfService.war \
	contexts/extz/BannerExtensibility.war \
	contexts/financess/FinanceSelfService.war \
	contexts/general_ss/BannerGeneralSsb.war \
	contexts/integrationapi/IntegrationApi.war \
	contexts/studentapi/StudentApi.war \

CONTEXTS_ADDITIONAL_PREREQS = \
	contexts/extz/xdb6.jar \

LOCAL_FILES = \
	contexts/accessmgmt/Dockerfile \
	contexts/eeamc/Dockerfile \
	contexts/integrationapi/Dockerfile \
	contexts/jenkins/Dockerfile \
	contexts/scripts/config.py \
	contexts/scripts/Dockerfile \
	contexts/studentapi/Dockerfile \
	volumes/jenkins/wgetrc \
	volumes/jenkins/start.sh \
	volumes/tomcat-env/env.properties \

TOMCAT_DOCKERFILES = \
	contexts/admincommon/Dockerfile \
	contexts/appnav/Dockerfile \
	contexts/bcm/Dockerfile \
	contexts/employee/Dockerfile \
	contexts/extz/Dockerfile \
	contexts/financess/Dockerfile \
	contexts/general_ss/Dockerfile \


include Makefile.local


usage:
	@echo "usage: make images|up|down|contexts|clean"
	@echo "Images must be built before \`make up\` will work."
	@echo ""
	@echo "example:"
	@echo "    make images"
	@echo "    make up"


images: contexts
	$(DOCKER_COMPOSE) --profile "*" build


update-images: contexts
	$(DOCKER_COMPOSE) --profile "*"  build --pull


up: volumes
	$(DOCKER_COMPOSE) $(AUTO_PROFILES) up -d


jenkins: user $(LOCAL_FILES)
	$(DOCKER_COMPOSE) build jenkins
	$(DOCKER_COMPOSE) up -d jenkins


haproxy: 
	$(DOCKER_COMPOSE) build haproxy
	$(DOCKER_COMPOSE) stop haproxy
	$(DOCKER_COMPOSE) up -d haproxy


scripts: scripts-context
	$(DOCKER_COMPOSE) build scripts


down:
	$(DOCKER_COMPOSE) --profile "*" down


stop:
	$(DOCKER_COMPOSE) --profile "*" stop


apis:
	$(DOCKER_COMPOSE) --profile apis up -d


ssb9:
	$(DOCKER_COMPOSE) --profile ssb9 up -d


restart: stop up


volumes: $(LOCAL_FILES)


# Create a prereq for each combination of tomcat context and tomcat prereq
contexts: $(foreach tomcat,$(TOMCATS),$(foreach prereq,$(TOMCAT_PREREQS),contexts/$(tomcat)/$(prereq)))
# Add additional prereqs to the `contexts` target
contexts: $(CONTEXTS_WAR_PREREQS)
contexts: $(CONTEXTS_ADDITIONAL_PREREQS)
contexts: $(LOCAL_FILES)
contexts: scripts
contexts: $(TOMCAT_DOCKERFILES)

scripts-context: contexts/scripts/Dockerfile contexts/scripts/config.py

# This rule says to copy any prereq within contexts/ from the `VPATH` directories 
contexts/%: $$(notdir %)
	cp $< $@


$(LOCAL_FILES): $$(@).dist Makefile.local
	cp $< $@
	echo Replacing variables in $@...
	@sed -i "s,\^BANNER9_ROOT\^,$(BANNER9_ROOT)," $@
	@sed -i "s/\^BANNER9_PROXY_USER\^/$(BANNER9_PROXY_USER)/" $@
	@sed -i "s/\^BANNER9_PROXY_PASSWORD\^/$(BANNER9_PROXY_PASSWORD)/" $@
	@sed -i "s/\^BANNER9_CONNECTION_USER\^/$(BANNER9_CONNECTION_USER)/" $@
	@sed -i "s/\^BANNER9_CONNECTION_PASSWORD\^/$(BANNER9_CONNECTION_PASSWORD)/" $@
	@sed -i "s/\^BANNER9_SESSION_TIMEOUT\^/$(BANNER9_SESSION_TIMEOUT)/" $@
	@sed -i "s/\^ORACLE_HOST\^/$(ORACLE_HOST)/" $@
	@sed -i "s/\^ORACLE_SID\^/$(ORACLE_SID)/" $@
	@sed -i "s/\^ORACLE_SERVICE_NAME\^/$(ORACLE_SERVICE_NAME)/" $@
	@sed -i "s,\^CAS_URL\^,$(CAS_URL)," $@
	@sed -i "s,\^CAS_LOGOUT_URL\^,$(CAS_LOGOUT_URL)," $@
	@sed -i "s,\^JENKINS_URL\^,$(JENKINS_URL)," $@
	@sed -i "s,\^JENKINS_NODE\^,$(JENKINS_NODE)," $@
	@sed -i "s,\^JENKINS_SECRET\^,$(JENKINS_SECRET)," $@
	@sed -i "s,\^ESM_WGET_USER\^,$(ESM_WGET_USER)," $@
	@sed -i "s,\^ESM_WGET_PASSWORD\^,$(ESM_WGET_PASSWORD)," $@
	@sed -i "s/\^HUBADO_HOST_USER\^/$(HUBADO_HOST_USER)/" $@
	@sed -i "s/\^HUBADO_HOST_UID\^/`id -u $(HUBADO_HOST_USER)`/" $@
	@sed -i "s,\^TIMEZONE\^,$(TIMEZONE)," $@
	@sed -i "s/\^INSTITUTION_NAME\^/$(INSTITUTION_NAME)/" $@


$(TOMCAT_DOCKERFILES): \
		contexts/scripts/make_tomcat_dockerfile.py \
		contexts/scripts/Dockerfile_tomcat.j2 \
		Makefile.local \
		scripts-context
	$(DOCKER_COMPOSE) run --rm scripts make_tomcat_dockerfile.py $@ > $@


# User to use inside containers
user:
	useradd -r $(HUBADO_HOST_USER) || true
	chown -R $(HUBADO_HOST_USER) volumes/


clean:
	rm -f contexts/*/context.xml
	rm -f contexts/*/server.xml
	rm -f contexts/*/setenv.sh
	rm -f contexts/*/ojdbc8.jar
	rm -f contexts/*/xdb6.jar
	rm -f contexts/*/*.trz
	rm -f contexts/*/footer.groovy
	rm -f $(CONTEXTS_WAR_PREREQS)
	rm -f $(CONTEXTS_ADDITIONAL_PREREQS)
	rm -f $(LOCAL_FILES)
	rm -f $(TOMCAT_DOCKERFILES)


prune:
	docker container prune -f
	docker volume prune -f
	docker network prune -f
	docker image prune -f
	docker system prune -f


test:
	$(DOCKER_COMPOSE) run scripts test_urls.py


.PHONY: down clean contexts images usage prune scripts

# vim: set noexpandtab sts=0:
