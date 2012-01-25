%import /sabayon/molecules/arm-base.common

# Release desc (the actual release description)
release_desc: armv7a Base

# Release Version (used to generate release_file)
release_version: 8

# Specify image file name (image file name will be automatically
# produced otherwise)
image_name: Sabayon_Linux_8_armv7a_BeagleBone_Base_16GB.img

# Specify the image file size in Megabytes. This is mandatory.
# To avoid runtime failure, make sure the image is large enough to fit your
# chroot data.
image_mb: 16000

# Path to boot partition data (MLO, u-boot.img etc)
source_boot_directory: /sabayon/beaglebone/boot
