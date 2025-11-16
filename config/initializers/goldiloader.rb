# Goldiloader configuration
# Automatic eager loading to prevent N+1 queries

# Goldiloader is enabled globally by default
# You can disable it for specific code blocks:
#
# Goldiloader.disabled do
#   # Code here runs without automatic eager loading
# end
#
# Or disable it for specific associations:
#
# class Post < ApplicationRecord
#   has_many :comments, -> { auto_include(false) }
# end
#
# Note: Bullet's unused eager loading detection is disabled
# to avoid conflicts with Goldiloader's automatic loading
