require 'omniauth'
require 'omniauth-oauth2'
require 'json/jwt'
require 'uri'

module OmniAuth
    module Strategies
        class UefId < OmniAuth::Strategies::OAuth2

            class Error < RuntimeError; end
            class ConfigurationError < Error; end
            class IntegrationError < Error; end

            attr_reader :authorize_url
            attr_reader :token_url
            attr_reader :certs

            option :client_options, {
                :site => 'https://sso.uef.edu.vn',
                :realm => 'university'
            }
            option :authorize_params,
            scope: 'openid email profile'

            def setup_phase
                super

                if (@authorize_url.nil? || @token_url.nil?) && !OmniAuth.config.test_mode

                    site = options.client_options.fetch(:site)
                    realm = options.client_options.fetch(:realm)

                    raise_on_failure = options.client_options.fetch(:raise_on_failure, false)

                    config_url = URI.join(site, "/realms/#{realm}/.well-known/openid-configuration")

                    log :debug, "Going to get UEF configuration. URL: #{config_url}"
                    response = Faraday.get config_url
                    if (response.status == 200)
                        json = JSON.parse(response.body)

                        @certs_endpoint = json["jwks_uri"]
                        @userinfo_endpoint = json["userinfo_endpoint"]
                        @authorize_url = URI(json["authorization_endpoint"]).path
                        @token_url = URI(json["token_endpoint"]).path

                        log_config(json)

                        options.client_options.merge!({
                            authorize_url: @authorize_url,
                            token_url: @token_url})
                        log :debug, "Going to get certificates. URL: #{@certs_endpoint}"
                        certs = Faraday.get @certs_endpoint
                        if (certs.status == 200)
                            json = JSON.parse(certs.body)
                            @certs = json["keys"]
                            log :debug, "Successfully got certificate. Certificate length: #{@certs.length}"
                        else
                            message = "Couldn't get certificate. URL: #{@certs_endpoint}"
                            log :error, message
                            raise IntegrationError, message if raise_on_failure
                        end
                    else
                        message = "UEF configuration request failed with status: #{response.status}. " \
                                  "URL: #{config_url}"
                        log :error, message
                        raise IntegrationError, message if raise_on_failure
                    end
                end
            end

            # Override callback_url to handle cases where the original URL contains query parameters
            def callback_url
                options[:redirect_uri] || (full_host + callback_path)
            end

            def log_config(config_json)
              log_uef_config = options.client_options.fetch(:log_uef_config, false)
              log :debug, "Successfully got UEF config"
              log :debug, "UEF SSO config: #{config_json}" if log_uef_config
              log :debug, "Certs endpoint: #{@certs_endpoint}"
              log :debug, "Userinfo endpoint: #{@userinfo_endpoint}"
              log :debug, "Authorize url: #{@authorize_url}"
              log :debug, "Token url: #{@token_url}"
            end

            def build_access_token
                verifier = request.params["code"]

                # debug token params
                log :debug, "Token params: #{token_params.to_hash}"

                client.auth_code.get_token(verifier,
                    {:redirect_uri => callback_url.gsub(/\?.+\Z/, "")}
                    .merge(token_params.to_hash(:symbolize_keys => true)),
                    deep_symbolize(options.auth_token_params))
            end

            def request_phase
                options.authorize_options.each do |key|
                  options[key] = request.params[key.to_s] if options[key].nil?
                end

                # debug options
                log :debug, "Authorize options: #{options.authorize_options.map { |k| [k, options[k]] }.to_h}"

                super
            end

            uid{ raw_info['sub'] }

            info do
            {
                :name => raw_info['name'],
                :email => raw_info['email'],
                :first_name => raw_info['given_name'],
                :last_name => raw_info['family_name'],
                :locale => raw_info['locale'],
                :picture => raw_info['picture']
            }
            end

            extra do
            {
                'raw_info' => raw_info,
                'id_token' => access_token['id_token']
            }
            end

            def raw_info
                id_token_string = access_token['id_token']
                raise ConfigurationError, "No id_token returned from UEF." if id_token_string.nil? || id_token_string.empty?
                raise ConfigurationError, "No certificates available to verify id_token." if @certs.nil? || @certs.empty?
                jwks = JSON::JWK::Set.new(@certs)
                id_token = JSON::JWT.decode id_token_string, jwks
            end

            OmniAuth.config.add_camelization('uef_id', 'UefId')
            OmniAuth.config.add_camelization('uefid', 'UefId')
            OmniAuth.config.add_camelization('uef', 'UefId')
        end
    end
end
