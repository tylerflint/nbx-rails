FROM ubuntu:16.04

# Dockerfile used to build and configure the live environment
# 
# Steps:
#   1 - Meta (labels, build args, evars)
#   2 - Install permanent packages that the live env will need
#   3 - Nginx configuration
#   4 - bundle install
#   5 - app source and config
#   6 - precompile assets
#   7 - set the command to run

# 1 - Meta
                                    
# Tell nanobox to route to port 3000
LABEL io.nanobox.http_port="3000"

# set the rails environment to production
ENV RAILS_ENV=production
# log rails to stdout
ENV RAILS_LOG_TO_STDOUT=true
# serve static assets through rails directly
ENV RAILS_SERVE_STATIC_FILES=true

# Set the image working directory to /app
WORKDIR /app

# 2 - Packages

# add passenger sources
RUN \
    apt-get update && \
    apt-get install -y dirmngr gnupg && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7 && \
    apt-get install -y apt-transport-https ca-certificates && \
    sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger xenial main > /etc/apt/sources.list.d/passenger.list' && \
    apt-get clean

# Install necessary packages that we want to exist in the final image
RUN \
    apt-get update && \
    apt-get install -y \
      # nginx + passenger
      nginx-extras passenger \
      # postgres dev headers for client
      postgresql-client && \
    # install bundler
    gem install bundler --no-ri --no-doc && \
    # clean the apt cache
    apt-get clean

# 3 - Nginx configuration
COPY .docker/prod/web/nginx /etc/nginx

# 4 - Bundler      
  
# NOTE:
#   
# The trick here is that we ONLY want to pull in the Gemfile and Gemfile.lock
# at this point. Since docker creates and caches layers, docker will only
# re-run a bundle install on push if the Gemfile actually changes.
# 

# copy the Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# We will need to install some packages for the bundle to succeed, but we
# won't need or want those in production. We can roll back the install
# after the bundle command to remove them. So we want to run the entire 
# set of commands in a single RUN, so we don't end up with layers of cruft
RUN \
    # install bundle dependencies
    apt-get install -y  build-essential && \
    # bundle install
    bundle install --without development test && \
    # cleanup
    apt-get purge -y  build-essential && \
    apt-get autoremove -y 
    
# 5 - App
                            
# Add the source code
COPY . /app

# copy the live config files on top of the app config
COPY .docker/prod/web/config ./config/

# 6 - Assets

RUN rails assets:precompile

# 7 - Run

# run the app via puma
CMD ["nginx"]
