# Part of code generating initrd: (C) 2018 Marek Wodzinski under MIT license

lookkernel() {
	NEWKERNELMD5=$(md5sum /boot/vmlinuz 2>/dev/null)
	if [ "$KERNELMD5" != "$NEWKERNELMD5" ]; then
		# echeck if initrd needs to be rebuild
		if readlink -s -q /boot/vmlinuz|grep -q generic; then
			echo "Looks like you have generic kernel, looking for initrd to rebuild"
			if [ ! -x /sbin/mkinitrd ]; then
				echo " no mkinitrd found, your system could be unusable after reboot!"
			elif [ ! -f /etc/mkinitrd.conf ]; then
				# no config found, we try to generate one for already running kernel

				# get initrd name if lilo is used
				if [ -x /sbin/lilo -a -f /etc/lilo.conf ]; then
					OUTPUT_IMAGE=""
					
					# guess lilo image from running kernel
					if cat /proc/cmdline|grep -q BOOT_IMAGE; then
						BOOT_IMAGE=$(cat /proc/cmdline|sed 's/.*BOOT_IMAGE=//'|cut -f 1 -d ' ')
						OUTPUT_IMAGE=$(/sbin/lilo -I "$BOOT_IMAGE" r)
						echo " found lilo entry ($BOOT_IMAGE) with initrd: $OUTPUT_IMAGE"
					else
						# iterate over all lilo images
						for image in $(/sbin/lilo -q|tr -d '*'); do
							if /sbin/lilo -I "$image"|grep -q -E "^/boot/vmlinuz(-generic)?$"; then
								OUTPUT_IMAGE=$(/sbin/lilo -I "$image" r)
								if [ "$OUTPUT_IMAGE" = "No initial ramdisk specified" ]; then
									OUTPUT_IMAGE=""
								else
									echo " found lilo entry ($image) with initrd: $OUTPUT_IMAGE"
								fi
							fi
						done
					fi
				else
					# best guess: default image
					OUTPUT_IMAGE="/boot/initrd.gz"
				fi

				# generate initrd
				echo " generating mkinitrd.conf"
				CLEAR_TREE=0 /usr/share/mkinitrd/mkinitrd_command_generator.sh -c -a "-o $OUTPUT_IMAGE" >/etc/mkinitrd.conf
			fi

			if [ -x /sbin/mkinitrd -a -f /etc/mkinitrd.conf ]; then
				echo " Regenerate initrd based on /etc/mkinitrd.conf? (Y/n)"
				answer
				if [ "$ANSWER" != "n" ] && [ "$ANSWER" != "N" ]; then
					echo " updating kernel version in mkinitrd"
					NEWVERSION=$(cat /var/log/packages/kernel-modules-*|grep modules.dep|head -n1|cut -f 3 -d '/')
					echo " found currently installed modules in version $NEWVERSION"
					sed -i.bak "s/^KERNEL_VERSION=.*/KERNEL_VERSION=$NEWVERSION/" /etc/mkinitrd.conf
					echo " regenerating mkinitrd"
					/sbin/mkinitrd -F
				fi
			fi
		
		fi
	
	
		# original lilo part
		if [ -x /sbin/lilo ]; then
			echo -e "\n
Your kernel image was updated.  We highly recommend you run: lilo
Do you want slackpkg to run lilo now? (Y/n)"
			answer
			if [ "$ANSWER" != "n" ] && [ "$ANSWER" != "N" ]; then
				/sbin/lilo
			fi
		else
			echo -e "\n
Your kernel image was updated and lilo is not found on your system.
You may need to adjust your boot manager(like GRUB) to boot appropriate
kernel."
		fi
	fi
}
