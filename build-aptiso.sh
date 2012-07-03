#!/bin/bash

# Builds an ISO image with an APT-compatible off-line repository for PTE-PMMC.
# Author: Laércio Benedito Sivali de Sousa <lbsousajr@gmail.com>
#
# Dependencies: apt-rdepends, aptitude, reprepro, genisoimage
#
# OBS: Requires GPG private key from "Comissão do ProInfo" (CPI) to digitally sign the repository.
# Only CPI members have this key, thus only they can build APT-ISO images for PTE-PMMC.

source /etc/lsb-release

codename=${codename:-${DISTRIB_CODENAME}}
version=${version:-${DISTRIB_RELEASE}}
pkglist="${*}"

case ${codename} in
	hardy)		fullcodename="Hardy Heron"	;;
	lucid)		fullcodename="Lucid Lynx"	;;
	maverick)	fullcodename="Maverick Meerkat"	;;
esac

tmpdir=${tmpdir:-~/aptisocache/${codename}}
outputdir=${outputdir:-~}
prefix=${prefix:-~/aptiso/${codename}}
ARCH=${ARCH:-`uname -m`}

if [[ "${ARCH}" = "x86_64" ]]
then
	ARCH=amd64
else
	ARCH=i386
fi

for i in apt-rdepends aptitude reprepro genisoimage gnupg-agent pinentry-curses
do
    if [ "x`dpkg -s ${i} | grep installed >& /dev/null`x" = "xx" ]
    then
        apt-get --yes --force-yes install ${i} || exit 1
    fi
done

if [ "x${CPI_GPG_KEY}x" != "xx" ]
then
    gpg --import -a ${CPI_GPG_KEY}
    eval $(gpg-agent --daemon)
fi

[[ -d ${tmpdir} ]] || mkdir -p ${tmpdir}
[[ -d ${prefix} ]] || mkdir -p ${prefix}
[[ -d ${prefix}/.disk ]] || mkdir ${prefix}/.disk
[[ -d ${prefix}/conf ]] || mkdir ${prefix}/conf

cat > /etc/apt/sources.list.d/oiteam-pte-pmmc-hardy.list <<EOF
deb http://ppa.launchpad.net/oiteam/pte-pmmc/ubuntu ${codename} main
deb-src http://ppa.launchpad.net/oiteam/pte-pmmc/ubuntu ${codename} main
EOF

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 9B232AB8

cat > ${prefix}/conf/distributions <<EOF
Origin: Equipe de Orientadores de Informática
Label: PTE-PMMC
Suite: ${codename}
Codename: ${codename}
Version: ${version}
Architectures: ${ARCH}
Components: main
SignWith: cpi.pmmc@gmail.com
Description: Pequeno repositório para distribuir os pacotes do Programa de Tecnologia Educacional da Prefeitura Municipal de Mogi das Cruzes - SP.
EOF

cat > ${prefix}/.disk/info <<EOF
PTE-PMMC for Ubuntu ${version} "${fullcodename}" ${ARCH} (`date +%Y-%m-%d`)
EOF

cat > ${prefix}/README.diskdefines <<EOF
#define DISKNAME  `cat ${prefix}/.disk/info`
#define TYPE  binary
#define TYPEbinary  CD1
#define ARCH  ${ARCH}
#define ARCH${ARCH}  CD1
#define DISKNUM  CD1
#define DISKNUMCD1  CD1
#define TOTALNUM  CD1
#define TOTALNUMCD1  CD1
EOF

echo
echo ">>> Atualizando a base de dados de pacotes nos repositórios..."
echo
apt-get update

echo
echo ">>> Construindo a árvore de dependências dos pacotes \"${pkglist}\"..."
echo
deplist=`apt-rdepends ${pkglist} | cut -d' ' -f1 | xargs`
cd ${tmpdir}

echo
echo ">>> Efetuando o download dos pacotes e todas as suas dependências..."
echo
aptitude download ${deplist} || exit 1

echo
echo ">>> Adicionando os pacotes e suas dependências ao repositório do CD..."
echo
for deb in ${tmpdir}/*
do
	reprepro ${ask_passphrase} -Vb ${prefix} includedeb ${codename} ${deb} || exit 1
done

echo
echo ">>> Adicionando a chave pública de assinatura digital do repositório à imagem do CD..."
echo
gpg --export -a "Comissão ProInfo" > ${prefix}/cpi-public-key.asc

echo
echo ">>> Criando a imagem do CD..."
echo
rm -rf ${prefix}/{conf,db}
image=${outputdir}/pte-pmmc-aptiso-${codename}-${version}.`date +%Y%m%d`-${ARCH}.iso

[[ -f ${image} ]] && rm ${image}
mkisofs -r -J -A "`cat ${prefix}/.disk/info`" -o ${image} ${prefix} || exit 1

#echo
#echo ">>> Removendo arquivos temporários..."
#echo
#rm -rf ${prefix} ${tmpdir}

echo
echo ">>> A imagem ISO do CD de instalação do repositório foi criada com sucesso!"
echo ">>> Tamanho da imagem: `du -h ${image} | cut -f1`B"
echo
