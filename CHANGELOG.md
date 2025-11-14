# 2.14.0 (2025-11-14)

Features:

* If something is calling your SCIM API with an unsupported content type but you still want to accept those requests, you can now configure a custom request sanitizer - addresses [a request from #161](https://github.com/pond/scimitar/pull/161#discussion_r2487464453) by `@aerodynamik` via [#166](https://github.com/pond/scimitar/pull/166)

# 2.13.0 (2025-09-12)

Fixes:

* _Actually_ works around an issue with Google Workspace; the PR intended for v2.12.0 did not get merged (facepalm - sorry!) - fixes [#142](https://github.com/pond/scimitar/issues/142) via [#161](https://github.com/pond/scimitar/pull/161) - thanks to `@kewnt`

Features:

* Support for `find_all_with` in the `scim_attributes_map`, to opt-in eliminate N+1 queries in some use cases - fixes [#157](https://github.com/pond/scimitar/issues/157) via [#164](https://github.com/pond/scimitar/pull/164/) - thanks to `@shuyahonda`

# 2.12.0 (2025-08-15)

Fixes:

* `PATCH` could fail to work as expected with extension schemas using complex type attributes. The problem arose if using a single `path` that pointed to the complex attribute with a Hash (object) value containing field-value pairs, rather than `path`s pointing all the way down to individual attribute fields with simple values - see [#160](https://github.com/pond/scimitar/pull/160) - thanks to `@aerodynamik`
* Works around an issue with Google Workspace - fixes [#142](https://github.com/pond/scimitar/issues/142) via [#161](https://github.com/pond/scimitar/pull/161) - thanks to `@kewnt`

Features:

* MongoDB support through Mongoid queries; see [#159](https://github.com/pond/scimitar/pull/159) for more - thanks to `@andriisereda-st`
* Proper support for fully custom authorisation, fixing [#158](https://github.com/pond/scimitar/issues/158) via [#162](https://github.com/pond/scimitar/pull/162) - thanks to `@NobodysNightmare`

# 2.11.0 (2025-03-05)

Maintenance:

* Repository transferred to its new official home at https://github.com/pond/scimitar/

Features:

* Supports Rails 8 (previously held back due to Rails 8 using a version of Ruby much newer than that upon which Scimitar wanted to insist) via [#154](https://github.com/pond/scimitar/pull/154)

Fixes:

* `SericeProviderConfig` endpoint does not output invalid attribute `uses_defaults` - fixes [#144](https://github.com/pond/scimitar/issues/144) via [#151](https://github.com/pond/scimitar/pull/151) - thanks to `@pbouda`

# 2.10.0 (2024-10-22)

Features:

* Custom controller mixins can now override more of the Scimitar base controller since the inclusion has been moved to the end of the file. This is particularly useful for overriding `rescue_from` declarations. See [#148](https://github.com/pond/scimitar/pull/148) for more - thanks to `@hrtshu`

Fixes:

* The `ResourceTypes` endpoint returned an invalid payload; this is now fixed per RFC 7644 via [#147](https://github.com/pond/scimitar/pull/147) - thanks to `@pbouda`

Other notes:

* `README.md` typo fix via [#145](https://github.com/pond/scimitar/pull/145) - thanks to `@pavelloz`

Gem developer notes:

* Local developer Ruby version (for `rbenv` users, at least) bumped to v3.3.5
* Gemspec development dependency versions bumped to latest, where relevant
* Dockerfile bumps PostgreSQL to v17

# 2.9.0 (2024-06-27)

Features:

* Override which core schema are returned in the `/Schemas` endpoint via new call `Scimitar::Engine.set_default_resources` (see [this code diff](https://github.com/pond/scimitar/pull/133/files#diff-b8ad01f8ed8a88f41a13938505a2050d3d3ff86af93a78a7690b273ece6b80bdR80)) - implements [#118](https://github.com/pond/scimitar/issues/118) requested by `@gsar` via [#133](https://github.com/pond/scimitar/pull/133)
* Opt-in feature to make the `/Schemas` endpoint walk resource attribute maps to determine _actual_ supported attributes and attribute mutability, rather than just reporting the literal schema definition; see the description of the `schema_list_from_attribute_mappings` configuration setting inside the template `config/initializers/scimitar.rb` file for details (or read it via the [code diff here](https://github.com/pond/scimitar/pull/135/files#diff-830211b739a7c7398083b7127d648b356f43d298713a2b3f0c13f2271b9d3c82R110)) - implements [#119](https://github.com/pond/scimitar/issues/119) requested by `@gsar` via [#135](https://github.com/pond/scimitar/pull/135)

Fixes:

* The `/Schemas` endpoint used to return a completely non-complaint response, but now returns a compliant `ListResponse`, as it always should have; there is no major version change to Scimitar with this fix, as it is hoped that this has no impact for most people (surely anyone who had attempted to use the endpoint would have already reported the issue!) - fixes [#117](https://github.com/pond/scimitar/issues/117) via [#133](https://github.com/pond/scimitar/pull/133) - thanks to `@gsar`
* A number of problems with extension schema are fixed so they should work much more reliably now, with `README.md` documentation updated in a few places for clairty; check there if you are still having trouble - fixes [#122](https://github.com/pond/scimitar/issues/122) via [#134](https://github.com/pond/scimitar/pull/134) - thanks to `@easym0de`

Other notes:

* For developers, note that debugging is now via the standard Ruby debugger - use e.g. `debugger` instead of `byebug` if you want to halt code and reach a debugging prompt during development work

# 2.8.0 (2024-06-13)

Features:

* Supports the [SCIM mechanism for requesting specific attributes](https://datatracker.ietf.org/doc/html/rfc7644#section-3.9) (noting however that schema ID URN prefixes are not supported; use only dotted attribute paths without such prefixes) - closes [89](https://github.com/pond/scimitar/issues/89) via [102](https://github.com/pond/scimitar/pull/102) and [127](https://github.com/pond/scimitar/pull/127) - thanks to `@xjunior`
* In a moment of déja vu from v2.7.3's Microsoft payload workarounds for [123](https://github.com/pond/scimitar/issues/123), handles a different kind of malformed filter sent by Microsoft Azure (Entra) in `GET` requests - implements [115](https://github.com/pond/scimitar/issues/115) requested by `@gsar` via [128](https://github.com/pond/scimitar/pull/128)
* Handles schema IDs (URNs) in filters of `GET` requests - implements [116](https://github.com/pond/scimitar/issues/116) requested by `@gsar` via [131](https://github.com/pond/scimitar/pull/131)

Fixes:

* Corrects schema for `name.givenName` and `name.familyName` in User, which previously specified these as required, but the SCIM specification says they are not - fixes [113](https://github.com/pond/scimitar/issues/113) reported by `@s-andringa` via [129](https://github.com/pond/scimitar/pull/129). If your code somehow _relies_ upon `name.givenName` and/or `name.familyName` being required in the User schema, you can patch this in your `config/initializers/scimitar.rb` file - for example:

    ```ruby
    Rails.application.config.to_prepare do
      Scimitar::Schema::Name.scim_attributes.find { |a| a.name == 'familyName' }.required = true
      Scimitar::Schema::Name.scim_attributes.find { |a| a.name == 'givenName'  }.required = true

      # ...
    end
    ```

# 2.7.3 (2024-06-11)

Features:

* As part of the above fix, schema ID handling was improved and extended with better test coverage. `PATCH` `add` and `replace` operations with `value` objects containing schema IDs both with or without attributes inline should now work reliably.

Fixes:

* Handles what I _think_ are technically malformed payloads from Azure (Entra), but since they seem unavoidable, it's important to handle them - should fix [123](https://github.com/pond/scimitar/issues/123) reported by `@eduardoborba`

# 2.7.2 (2024-03-27)

Fixes:

* The implementation of non-returned SCIM fields turned out to inadvertently prevent their subsequent update (so SCIM _updates_ to e.g. passwords would fail); fixed [105](https://github.com/pond/scimitar/issues/105) and (in passing) [6](https://github.com/pond/scimitar/issues/6), via [109](https://github.com/pond/scimitar/pull/109) - thanks to `@xjunior`
* The case-insensitive, String or Symbol access Hash class documented itself as preserving case but did not, reported in [98](https://github.com/pond/scimitar/issues/98), also via [109](https://github.com/pond/scimitar/pull/109) - thanks to `@s-andringa`

# 2.7.1 (2024-01-16)

Fixes:

* Some dependency chain gems have stopped supporting Ruby 2.7, so a `Gemfile.lock` for local development generated under Ruby 3 does not work under Ruby 2.7. Solved by removing `Gemfile.lock` entirely, so that an errant Nokogiri lock in `scimitar.gemspec` used previously as a workaround could also be removed.

# 2.7.0 (2024-01-15)

Warning:

* The default `type` value of `work` in the `address` complex type has been removed, in line with all other comparable complex types, via [87](https://github.com/pond/scimitar/issues/87) / [92](https://github.com/pond/scimitar/pull/92) - thanks to `@s-andringa`.
* **This is unlikely to break client code but there is a *small* chance of issues if you relied upon the default**. Please check your implementation if at all concerned. It doesn't seem risky enough to force a major version bump to comply with semantic versioning.

Features:

* Allow a block to be passed to `Scimitar::ActiveRecordBackedResourcesController#create`, `#update` and `#replace`. This behaves in a manner analogous to passing a block to `Scimitar::ActiveRecordBackedResourcesController#destroy`, wherein the block implementation becomes responsible for destroying the record the block is given; in the case of `#create`, `#update` and `#replace`, the block is passed the new or updated record and is responsible for persisting it.

Fixes:

* Fix for Microsoft SCIM Validator; pathless `replace` operations can use dot-path notation in the `value` section, via [69](https://github.com/pond/scimitar/pull/69) - thanks to `@wooly`
* Basic and token authentication blocks now operate in the context of the application's controller, via [88](https://github.com/pond/scimitar/pull/88) - thanks to `@tejanium`
* Exception handling for records during saving is improved and extensible, via [91](https://github.com/pond/scimitar/pull/91)

Maintenance:

* Bump local development Ruby to v3.3.0, including it in the test matrix and in effect creating "official" support for that Ruby version.

# 2.6.1 (2023-11-15)

* Always returns a `Content-Type` header with value `application/scim+json; charset=utf-8` in any response, since that's the only format the gem can write. Fixes [#59](https://github.com/pond/scimitar/issues/59).
* Uses the more common header name form of `WWW-Authenticate` rather than the Rack-like `WWW_AUTHENTICATE` in responses.

# 2.6.0 (2023-11-14)

Features:

* Schema location URLs are generated by the controller, making overrides simpler, via [#71](https://github.com/pond/scimitar/pull/71) - thanks to `@s-andringa`
* A block can be passed to `ActiveRecordBackedResourcesController#save!`, making it easier to override with custom behaviour since you won't have to worry about things like uniqueness constraint exceptions, via [#73](https://github.com/pond/scimitar/pull/73) - thanks to `@s-andringa`
* Those who want an invariant local testing setup can now consider using Docker via [#77](https://github.com/pond/scimitar/pull/77) - thanks to `@osingaatje`

Fixes:

* Multi-valued simple types are now correctly rendered via [74](https://github.com/pond/scimitar/pull/74) - thanks to `@s-andringa`
* Sensitive fields are no longer rendered (fixes [#56](https://github.com/pond/scimitar/issues/56) via [#80](https://github.com/pond/scimitar/pull/80) - thanks to `@kuldeepaggarwal`.

# 2.5.0 (2023-09-25)

Many thanks to `@xjunior`, who contributed a series of improvements and fixes present in this version. New features:

* Allow writable complex types in custom extensions via [#61](https://github.com/pond/scimitar/pull/61)
* Allow complex queries via table joins via [#62](https://github.com/pond/scimitar/pull/62)

Fixes:

* Much better error message raised if `PatchOp` misses operations in [#65](https://github.com/pond/scimitar/pull/65)
* Combined logical groups generate working queries with [#66](https://github.com/pond/scimitar/pull/66)

# 2.4.3 (2023-09-16)

* Maintenance release which merges a warning removal patch in [#54](https://github.com/pond/scimitar/pull/54) (thanks to `@sobrinho` for the contribution) via [#63](https://github.com/pond/scimitar/pull/63) and it is the changes in the latter which are brought into Scimitar V2 to keep a minimal overall diff between the V1 and V2.

# 2.4.2 (2023-03-21)

* Fix shortcoming in `Content-Type` header handling via [#51](https://github.com/pond/scimitar/pull/51). Thanks to `@Flixt` for the contribution.

# 2.4.1 (2023-03-02)

* Address https://github.com/pond/scimitar/issues/48 by adapting https://github.com/pond/scimitar/issues/49, so that extension schemas work properly. Missing documentation in `README.md` addressed. Thanks to `@bettysteger` and `@MorrisFreeman` for the contribution.

# 2.4.0 (2023-01-27)

* Address https://github.com/pond/scimitar/issues/43 - allows Microsoft-style payloads for removing Users from Groups, with a special case exception for hypothetical inbound SCIM calls originating from Salesforce software. For more details of the fix, please see https://github.com/pond/scimitar/pull/45.

# 2.3.0 (2023-01-17)

* Address https://github.com/pond/scimitar/issues/35. Declaring primary key in the ActiveRecord model would solve most of the problems described, but v2.2.0 did introduce a default order clause that would trip up a model with a different primary key name; this is now fixed. In any case, it may be possible to avoid declaring the primary key override in the model entirely if using Scimitar v2.3.0, should that be your wish. This is in effect an edge case new feature, which is why the gem's minor version has been bumped up.

# 2.2.0 (2023-01-13)

* Bump local development Ruby to v3.2.0, including it in the test matrix and in effect creating "official" support for that Ruby version.

# 2.1.3 (2023-01-09)

* Fix https://github.com/pond/scimitar/issues/36 - filters are case-sensitive for special cases of `id`, `externalId` and `meta.*` attributes. A model must still declare if and how these are searchable via its `::scim_queryable_attributes` implementation, just as with any other attribute.

# 2.1.2 (2023-01-09)

* Fix https://github.com/pond/scimitar/issues/37 - filters now correctly support case insensitive attribute names.

# 2.1.1 (2022-11-04)

* Merged https://github.com/pond/scimitar/pull/29, fixing an issue caused by an unhandled form of payload sent by Okta. Thanks to `@jasonopslevel` for the contribution.

# 2.1.0 (2022-07-14)

* Merged https://github.com/pond/scimitar/pull/17 (more detailed errors), https://github.com/pond/scimitar/pull/18 (`primary` attribute added to Address schema) and https://github.com/pond/scimitar/pull/19 (configurable required-or-optional `value` attributes in VDTP-derived types). Thanks for the contributions, `@pelted`!
* Noted closed PR https://github.com/pond/scimitar/pull/25 and implemented a configurable exception reporting hook for people who might want that kind of feature. See [engine configuration option `exception_reporter`](https://github.com/pond/scimitar/blob/main/config/initializers/scimitar.rb) for details.

# 2.0.2 (2022-06-15)

* Address https://github.com/pond/scimitar/issues/20 by better handling content type in requests:

  - Since https://github.com/MicrosoftDocs/azure-docs/issues/94189#issuecomment-1154227613 indicates that _no_ header is sent for `GET` methods while a correct header is sent for others; that is inline with the RFC and we should handle a lack of content type in the `GET` case. This was not the case in Scimitar v2.0.1 and earlier.
  - Ultimately we must expect attackers to send junk data in attempts to find vulnerabilities in JSON parsing, so the header presence can't really be trusted and the JSON parser must simply be robust. As a result, this patch version of the gem will assume an `application/scim+json` content type for _any_ inbound request that specifies no other type, regardless of HTTP method used. Requests are only rejected if a `Content-Type` header explicitly states that the content is of some unsupported type.

# 2.0.1 (2022-04-20)

* Merges https://github.com/pond/scimitar/pull/15 from `AbeerKhakwani`, fixing an issue with AD and the Meta object.

# 2.0.0 (2022-03-04)

* Requires Rails 7. Supports Ruby 3, but still works on 2.7.

## Upgrading from Scimitar 1.x.y

* Your `config/initializers/scimitar.rb` might need to be enclosed within a `Rails.application.config.to_prepare do...` block to avoid `NameError: uninitialized constant...` exceptions arising due to autoloader problems:

    ```ruby
    Rails.application.config.to_prepare do
      Scimitar.engine_configuration = Scimitar::EngineConfiguration.new({
        # ...
      end
    end
    ```

* If you use `Scimitar::Errors#add_errors_from_hash`, note that the previously-unnamed first parameter is now explicitly named `errors_hash`. This avoids potential ambiguity and confusion/errors with Ruby 3's more strict rules for named parameter and hash mixtures in both method definitions and method calls. For example:

    ```ruby
    # Old code...
    user.add_errors_from_hash(key: 'some key')
    # ...becomes:
    user.add_errors_from_hash(errors_hash: {key: 'some key'})

    # Old code...
    user.add_errors_from_hash({key: 'some key'}, prefix: 'some prefix')
    # ...becomes:
    user.add_errors_from_hash(errors_hash: {key: 'some key'}, prefix: 'some prefix')
    ```



# 1.3.1 (2022-11-04)

* Back-ports features from v2.1.1 for Rails 6 users.

# 1.3.0 (2022-07-14)

* Back-ports features from v2.1.0 for Rails 6 users.

# 1.2.1 (2022-06-15)

* Back-ports fixes from v2.0.1 and v2.0.2 for Rails 6 users.

# 1.2.0 (2021-09-27)

* Updated for RIPA branding.
* Ruby and gem version maintenance updates.

# 1.1.0 (2021-09-15)

* Implement case insensitivity for attributes (fixes [issue #7](https://github.com/pond/scimitar/issues/7)).

# 1.0.3 (2020-03-24)

* More robust path filter parsing for `PATCH` operations; previously, a path filter such as `value eq "Something With Spaces"` would have been rejected.

# 1.0.2 (2020-03-24)

* Add Travis support for CI.
* Adjust `scimitar.gemspec` a bit more for CI and now that we're public in RubyGems, with a `Gemfile.lock` bump on Scimitar itself (overlooked in 1.0.1).

# 1.0.1 (2020-03-24)

* Added source code link to `scimitar.gemspec` metadata for RubyGems.

# 1.0.0 (2020-03-24)

* Initial public release.
