# Omniauth::Uef

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'omniauth-uef'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install omniauth-uef

## Use with Uef >= 17 (Quarkus distribution)
In version 17 of Uef, `/auth` was removed from the default context path. (See Issue [#29](https://github.com/ccrockett/omniauth-uef/issues/29))  
In order to reduce breaking existing user's setup, this gem assumes `/auth` as the default context.  
__So if you want to use Uef 17 or greater then you must do one of the following:__

1. Pass in `--http-relative-path '/auth'` option with the uef start command
2. Pass in a empty string for you base_url client_option:  
  `client_options: {base_url: '', site: 'https://example-sso.uef.edu.vn', realm: 'example-realm'}`

## Usage

`OmniAuth::Strategies::Uef` is simply a Rack middleware. Read the OmniAuth docs for detailed instructions: https://github.com/intridea/omniauth.

Here's a quick example, adding the middleware to a Rails app in `config/initializers/omniauth.rb`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :uefid, 'Example-Client', '19cca35f-dddd-473a-bdd5-03f00d61d884',
    client_options: {site: 'https://example-sso.uef.edu.vn', realm: 'example-realm'},
    name: 'uef'
end
```
This will allow a POST request to `auth/uef` since the name is set to uef

Or using a proc setup with a custom options:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  SETUP_PROC = lambda do |env|
    request = Rack::Request.new(env)
    organization = Organization.find_by(host: request.host)
    provider_config = organization.enabled_omniauth_providers[:uefid]

    env["omniauth.strategy"].options[:client_id] = provider_config[:client_id]
    env["omniauth.strategy"].options[:client_secret] = provider_config[:client_secret]
    env["omniauth.strategy"].options[:client_options] = { site: provider_config[:site],  realm: provider_config[:realm] }
  end

  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :uefid, setup: SETUP_PROC
  end
end
```


## Devise Usage
Adapted from [Devise OmniAuth Instructions](https://github.com/plataformatec/devise/wiki/OmniAuth:-Overview)

```ruby
# app/models/user.rb
class User < ApplicationRecord
  #...
  devise :omniauthable, omniauth_providers: %i[uefid]
  #...
end

# config/initializers/devise.rb
config.omniauth :uefid, "Example-Client-Name", "example-secret-if-configured", client_options: { site: "https://example-sso.uef.edu.vn", realm: "example-realm" }, :strategy_class => OmniAuth::Strategies::UefId

# Below controller assumes callback route configuration following
# in config/routes.rb
Devise.setup do |config|
  # ...
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
end

# app/controllers/users/omniauth_callbacks_controller.rb
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def uefid
    Rails.logger.debug(request.env["omniauth.auth"])
    @user = User.from_omniauth(request.env["omniauth.auth"])
    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
    else
      session["devise.uefid_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end

  def failure
    redirect_to root_path
  end
end

```

## Configuration
  * __Base Url other than /auth__  
  This gem tries to get the uef configuration from `"#{site}/auth/realms/#{realm}/.well-known/openid-configuration"`. If your uef server has been setup to use a different "root" url other than `/auth` then you need to pass in the `base_url` option when setting up the gem:
    ```ruby
    Rails.application.config.middleware.use OmniAuth::Builder do
      provider :uefid, 'Example-Client', '19cca35f-dddd-473a-bdd5-03f00d61d884',
        client_options: {site: 'https://example-sso.uef.edu.vn', realm: 'example-realm', base_url: '/authorize'},
        name: 'uef'
    end
    ```
  * __Pass params from request thru to Uef__  
  See [PR #24](https://github.com/ccrockett/omniauth-uef/pull/24) for details on how to configure this.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ccrockett/omniauth-uef. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Omniauth::Uef project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ccrockett/omniauth-uef/blob/master/CODE_OF_CONDUCT.md).
