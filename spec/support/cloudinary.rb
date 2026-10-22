# Building a delivery URL needs a cloud name even though only the :vision
# specs reach Cloudinary, so give one to machines without CLOUDINARY_URL.
Cloudinary.config.cloud_name ||= "licketysplit-test"
