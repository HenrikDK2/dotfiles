#!/bin/sh

reconfigure () {
	sed -i 's/_processor_opt=""/_processor_opt="zen2"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_compiler=""/_compiler="llvm"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_noccache="false"/_noccache="true"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_menunconfig=""/_menunconfig="false"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_cpusched=""/_cpusched="pds"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_sched_yield_type=""/_sched_yield_type="0"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_acs_override=""/_acs_override="true"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_rr_interval=""/_rr_interval="1"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_ftracedisable="false"/_ftracedisable="true"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_numadisable="false"/_numadisable="true"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_anbox=""/_anbox="false"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_tickless=""/_tickless="2"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_smt_nice=""/_smt_nice="true"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_timer_freq=""/_timer_freq="1000"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_lto_mode=""/_lto_mode="full"/g' ~/.my_scripts/linux-tkg/customization.cfg
	sed -i 's/_custom_pkgbase=""/_custom_pkgbase="tkg"/g' ~/.my_scripts/linux-tkg/customization.cfg
}

if [ -f "/boot/loader/entries/tkg.conf" ]; then
	if [ -d "$HOME/.my_scripts/linux-tkg" ];
	then
		cd ~/.my_scripts/linux-tkg
		rm -rf *.zst *.zx *.patch ./logs pkg kernelconfig.new config.x86_64 cleanup BIG_UGLY_FROGMINER
		git fetch origin master
		git reset --hard origin/master
		reconfigure
	else
		git clone https://github.com/Frogging-Family/linux-tkg.git ~/.my_scripts/linux-tkg
		reconfigure
	fi

	cd ~/.my_scripts/linux-tkg
	chmod +x ./install.sh
	rm -rf ~/.my_scripts/linux-tkg/*.xz
	makepkg -si --noconfirm
fi

