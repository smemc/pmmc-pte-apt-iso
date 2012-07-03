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

tmpdir=${tmpdir:-~/repocache/${codename}}
outputdir=${outputdir:-~}
prefix=${prefix:-~/repocd/${codename}}
arch=${arch:-`uname -m`}

if [[ "${arch}" = "x86_64" ]]
then
	arch=amd64
else
	arch=i386
fi

[[ -d ${tmpdir} ]] || mkdir -p ${tmpdir}
[[ -d ${prefix} ]] || mkdir -p ${prefix}
[[ -d ${prefix}/.disk ]] || mkdir ${prefix}/.disk
[[ -d ${prefix}/conf ]] || mkdir ${prefix}/conf

cat > ${prefix}/conf/distributions <<EOF
Origin: Equipe de Orientadores de Informática
Label: PTE-PMMC
Suite: ${codename}
Codename: ${codename}
Version: ${version}
Architectures: ${arch}
Components: pte
SignWith: cpi.pmmc@gmail.com
Description: Pequeno repositório para distribuir os pacotes do Programa de Tecnologia Educacional da Prefeitura Municipal de Mogi das Cruzes - SP.
EOF

cat > ${prefix}/.disk/info <<EOF
PTE-PMMC for Ubuntu ${version} "${fullcodename}" ${arch} (`date +%Y-%m-%d`)
EOF

cat > ${prefix}/README.diskdefines <<EOF
#define DISKNAME  `cat ${prefix}/.disk/info`
#define TYPE  binary
#define TYPEbinary  CD1
#define ARCH  ${arch}
#define ARCH${arch}  CD1
#define DISKNUM  CD1
#define DISKNUMCD1  CD1
#define TOTALNUM  CD1
#define TOTALNUMCD1  CD1
EOF

#echo
#echo ">>> Atualizando a base de dados de pacotes nos repositórios..."
#echo
#sudo aptitude update

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
image=${outputdir}/pte-pmmc-repocd-${codename}-${version}.`date +%Y%m%d`-${arch}.iso

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
