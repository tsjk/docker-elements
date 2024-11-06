FROM gentoo/portage:latest as portage

FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM}} gentoo/stage3:latest

COPY --from=portage /var/db/repos/gentoo /var/db/repos/gentoo

COPY ./.functions.sh /.functions.sh

RUN	   . /.functions.sh\
	&& echo -e "\nFEATURES=\"-ipc-sandbox -mount-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox\"" >> /etc/portage/make.conf\
	&& emerge -p -q app-eselect/eselect-repository > /dev/null 2>&1 && eselect news read > /dev/null 2>&1\
	&& __fetch_and_merge app-eselect/eselect-repository dev-vcs/git

RUN	   eselect repository add bitcoin git https://gitlab.com/bitcoin/gentoo.git\
	&& mkdir -p /etc/portage/package.accept_keywords\
	&& echo '*/*::gentoo ~*' > /etc/portage/package.accept_keywords/_gentoo_repository\
	&& echo '*/*::bitcoin ~*' > /etc/portage/package.accept_keywords/_bitcoin_repository\
	&& echo '>=net-p2p/elements-23.2.5' >> '/etc/portage/package.mask/net-p2p:elements'\
	&& mkdir -p /etc/portage/package.accept_keywords\
	&& echo '~net-p2p/elements-23.2.4::bitcoin **' >> '/etc/portage/package.accept_keywords/net-p2p:elements'\
	&& mkdir -p /etc/portage/package.use\
	&& echo 'dev-libs/libsecp256k1-zkp asm bppp ecdh ecdsa-adaptor ecdsa-s2c ellswift experimental extrakeys generator musig rangeproof recovery schnorrsig surjectionproof whitelist' >> '/etc/portage/package.use/net-p2p:elements'\
	&& echo 'net-p2p/elements asm berkdb cli daemon examples external-signer man sqlite system-leveldb system-libsecp256k1 zeromq -dbus -gui -nat-pmp -qrcode -systemtap -upnp' >> '/etc/portage/package.use/net-p2p:elements'\
	&& echo 'sys-libs/db cxx' >> '/etc/portage/package.use/net-p2p:element'

RUN	   . /.functions.sh\
	&& emaint sync -r bitcoin\
	&& emerge -1 -q -u sys-apps/portage\
	&& __fetch_and_merge net-p2p/elements

RUN	   . /.functions.sh\
	&& __fetch_and_merge\
		app-admin/su-exec\
		app-admin/sudo\
		net-misc/socat\
		sys-fs/inotify-tools\
		sys-process/tini\
	&& rm -rf /.functions.sh /var/cache/distfiles /var/db/repos/gentoo

COPY --chmod=755 ./entrypoint.sh /entrypoint.sh

ENV \
	ELEMENTSD_HOME=/var/lib/elementsd\
	ELEMENTSD_CONFIG=/etc/elements\
	ELEMENTSD_CHAIN=liquidv1
ENV \
	ELEMENTSD_RPC_PORT=7041\
	ELEMENTSD_PORT=7042\
	LIQUIDV1_DATA=${ELEMENTSD_HOME}/${ELEMENTSD_CHAIN}

VOLUME "${ELEMENTSD_HOME}" "${ELEMENTSD_CONFIG}"

EXPOSE ${ELEMENTSD_PORT} ${ELEMENTSD_RPC_PORT}

ENTRYPOINT [ "/usr/bin/tini", "-g", "--", "/entrypoint.sh" ]

CMD ["elementsd"]
