#!/bin/bash

cl_img_select_bin=/usr/cumulus/bin/cl-img-select
syseeprom_bin=/usr/cumulus/bin/decode-syseeprom
this_script=$(basename $(realpath $0))
args=":l:o:s:hnv"

usage()
{
    echo "usage: $this_script [-l LABEL] [OPTIONS] -s PORT:PART [ -s PORT:PART]"
    cat <<EOF

Perform an EEPROM dump of the pluggable module PART on PORT.

COMMAND LINE OPTIONS

        -h
                Help.  Print this message.

        -n
                Dry run.  Do not perform any actions.

        -v
                Be verbose. Print what is happening.

        -o
                Use the following output directory.
                (default: /mnt/usb/interop_pluggables_results)

        -l
                Use the following label for this EEPROM dump run.
                (default: UNKNOWN)

        -s
                Use the following PORTs and SERIAL NUM using a ':' to
                separate PORT and SERIAL NUM.  Multiple PORT:SERIAL NUM can be
                specified by specifying another -s PORT:SERIAL NUM.
EOF
}

determine_cl_version()
{
    local version=$("$cl_img_select_bin" -d | grep active | sed 's/^.*: //g')
    echo "$version"
}

determine_eeprom_results()
{
    local results=$("$syseeprom_bin" -t board)
    echo "$results"
}

determine_manufacturer()
{
    local results=$1
    local mfg=$(echo "$results" | egrep 0x2D | sed -r 's/^.*0x2D  ([0-9]|[0-9][0-9]) //g')
    # sanitize the manufacturer
    if [ `echo "$mfg" | wc -w` == 1 ] ; then
        mfg=$(echo "$mfg" | sed -e 's/.*/\L&/' -e 's/./\U&/')
    else
        mfg=$(echo "$mfg" | sed 's/\s//g')
    fi
    echo "$mfg"
}

determine_product()
{
    local results=$1
    local prod=$(echo "$results" | egrep 0x21 | awk '{print $(NF-0)}' | sed -e 's/ //g')
    echo "$prod"
}

determine_service_tag()
{
    local results=$1
    local tag=$(echo "$results" | egrep 0x2F | awk '{print $(NF-0)}' | sed -e 's/ //g')
    echo "$tag"
}

determine_serial_num()
{
    local results=$1
    local num=$(echo "$results" | egrep 0x23 | awk '{print $(NF-0)}' | sed -e 's/ //g')
    echo "$num"
}

determine_output_dir()
{
    local dir="$1"
    local cl_ver="$2"
    local mfg="$3"
    local prod="$4"
    local output_dir="${dir}/${cl_ver}/${mfg}_${prod}/"
    echo "$output_dir"
}

create_output_dir()
{
    local dir="$1"
    local verbose="$2"
    local dry_run="$3"
    [ "$verbose" = "yes" ] && echo "Create output directory: $dir"
    # TODO
    #if [ ! -w "$dir" ] ; then
    #    echo "Can't write to directory ${dir}"
    #    exit 1
    if [ -d "$dir" ] ; then
        [ "$verbose" = "yes" ] && echo "output directory: $dir exists"
    else
        if [ "$dry_run" = "yes" ] ; then
            echo "mkdir -p $dir"
        else
            mkdir -p $dir
        fi
        [ "$verbose" = "yes" ] && echo "output directory: $dir created"
    fi
}

dump_firmware()
{
    local dir="$1"
    local eeprom="$2"
    local verbose="$3"
    local dry_run="$4"
    [ "$verbose" = "yes" ] && echo "Dumping firmware to directory: $dir"
    if [ `uname -p` == "powerpc" ] ; then
        if [ "$dry_run" = "yes" ] ; then
            echo "fw_printenv"
        else
            fw_printenv > "${dir}/fw_printenv.txt"
        fi
    else
        if [ "$dry_run" = "yes" ] ; then
            echo "dmidecode"
        else
            dmidecode > "${dir}/dmidecode.txt"
        fi
    fi
    echo "${eeprom}" > "${dir}/decode-syseeprom.txt"
}

determine_module_sn()
{
    local results="$1"
    local mod="$2"
    local sn=$(echo "$results" | grep "Vendor SN" | awk '{print $(NF-0)}' | sed -e 's/ //g')
    if [ -z "$sn" ] ; then
        sn="UNKNOWN${mod}"
    fi
    echo "$sn"
}

determine_module_pn()
{
    local results="$1"
    local part_num=$(echo "$results" | grep "Vendor PN" | awk '{print $(NF-0)}' | sed -e 's/ //g')
    if [ -z "$part_num" ] ; then
        part_num="UNKNOWN"
    fi  
    echo "$part_num"
}

determine_module_pn_human()
{
    local part_num="$1"
    part_num=$(echo "$part_num" | sed -e \
      's/AFBR-79EBPZ-CS1/40GBASE-SR-BD/g' -e \
      's/QSFP-SR4/40GBASE-SR4/g' -e \
      's/L45593-D108-B50/40GBASE-CR4-Passive/g' -e \
      's/AFBR-79EIPZ-CS1/40GBASE-SR4/g' -e \
      's/AFBR-79E4Z-D-JU1/40GBASE-SR4/g' -e \
      's/L45593-D178-B50/40GBASE-CR4-Passive-Breakout/g' -e \
      's/MFM1T02A-SR/10GBASE-SR/g' -e \
      's/FTLX8571D3BCL-J1/10GBASE-SR/g' -e \
      's/SFP-10G-SR/10GBASE-SR/g' -e \
      's/FTLX8571D3BCL-C2/10GBASE-SR/g' -e \
      's/FTLX1472M3BCL/10GBASE-LR/g' -e \
      's/FTLX1471D3BCL-CS/10GBASE-LR/g' -e \
      's/SFP-10G-LR/10GBASE-LR/g' -e \
      's/FTLX1471D3BCL-J1/10GBASE-LR/g' -e \
      's/624380003/10GBASE-CR4-Passive/g' -e \
      's/AFBR-5715PZ-JU1/1000BASE-SX/g'
    )
    echo "$part_num"
}

determine_module_vn_name()
{
    local results="$1"
    local part_num="$2"
    local name=$(echo "$results" | grep "Vendor name" | sed -e 's/^.*name.*: //g' -e 's/ //g')
    if [ -z "$name" ] ; then
        name="UNKNOWN"
    elif [[ "$part_num" =~ "-(CS|CS1)$" ]] ; then
        name="Cisco"
    elif [[ "$part_num" =~ "-(J1|JU1)$" ]] ; then
        name="Juniper"
    else
        name=$(echo "$name" | sed -e \
          's/Arista Network.*/Arista/g' -e \
          's/CISCO.*/Cisco/g' -e \
          's/FINISAR.*/Finisar/g' -e \
          's/Mellanox.*/Mellanox/g' -e \
          's/Amphenol.*/Amphenol/g' -e \
          's/OEM.*/10Gtek/g'
        )
    fi
    echo "$name"
}

probe_port()
{
    local port=$1
    local dir=$2
    local label=$3
    local part=$4
    local verbose=$5
    local dry_run=$6

    [ "$verbose" = "yes" ] && echo "Bringing up link on $port"
    if [ "$dry_run" = "yes" ] ; then
        echo "ip link set up dev $port"
    else
        ip link set up dev $port
    fi
    local ethtool_results=$(ethtool -m $port)

    if [ `wc -l <<< "$ethtool_results"` -lt 3 ] ; then
        echo "No module data found for $port"
        return 1
    fi

    module_sn=$(determine_module_sn "{$ethtool_results}" "${port}")
    module_pn=$(determine_module_pn "${ethtool_results}")
    module_pn_human=$(determine_module_pn_human "${module_pn}")
    module_vn_name=$(determine_module_vn_name "${ethtool_results}" "${module_pn}")

    echo "Found $module_vn_name - $module_pn / $module_pn_human - $module_sn"
    echo "On Port $port"
    local dut_dir="${dir}/${module_vn_name}_${label}/"

    [ "$verbose" = "yes" ] && echo "Create DUT output directory: $dut_dir"
    if [ -d "$dut_dir" ] ; then
        [ "$verbose" = "yes" ] && echo "DUT output directory: $dut_dir exists"
    else
        if [ "$dry_run" = "yes" ] ; then
            echo "mkdir -p $dut_dir"
        else
            mkdir -p $dut_dir
        fi
        [ "$verbose" = "yes" ] && echo "DUT output directory: $dut_dir created"
    fi

    if [ "$dry_run" = "yes" ] ; then
        echo "ethtool -m $port"
        echo "hexdump -C eeprom"
    else
        ethtool -m $port > "${dut_dir}/${module_pn}_${module_sn}.ethtool.txt"
        local p_port=$(echo "$port" | sed 's/swp/port/')
        local eeprom=$(egrep -l "^${p_port}$" /sys/class/eeprom_dev/*/label | sed 's/label/device\/eeprom/')
        hexdump -C "$eeprom" > "${dut_dir}/${module_pn}_${module_sn}.hexdump.txt"

        echo "$label" > "${dut_dir}/${module_pn}_${module_sn}.label_PN.txt"
        echo "$part" > "${dut_dir}/${module_pn}_${module_sn}.label_SN.txt"
    fi

    local addr=$(echo "$port" | sed 's/swp//')

    [ "$verbose" = "yes" ] && echo "Adding IP 100.64.42.${addr}/24 on $port"
    if [ "$dry_run" = "yes" ] ; then
        echo "ip addr replace 100.64.42.${addr}/24 dev $port"
    else
        ip addr replace 100.64.42.${addr}/24 dev $port
    fi

    [ "$verbose" = "yes" ] && echo "Pinging 100.64.42.${addr}/24"
    if [ "$dry_run" = "yes" ] ; then
        echo "ping -c 3 100.64.42.${addr}"
    else
        ping -c 3 100.64.42.${addr}
    fi

    [ "$verbose" = "yes" ] && echo "Removing IP 100.64.42.${addr}/24 on $port"
    if [ "$dry_run" = "yes" ] ; then
        echo "ip addr del 100.64.42.${addr}/24 dev $port"
    else
        ip addr del 100.64.42.${addr}/24 dev $port
    fi

    [ "$verbose" = "yes" ] && echo "Bringing up link on $port"
    if [ "$dry_run" = "yes" ] ; then
        echo "ip link set down dev $port"
    else
        ip link set down dev $port
    fi
}

dry_run=no
verbose=no
label="UNKNOWN"
output_dir=/mnt/usb/interop_pluggables_results
ports=()
while getopts "$args" a ; do
    case $a in
        h)
            usage
            exit 0
            ;;
        v)
            verbose=yes
            ;;
        n)
            dry_run=yes
            ;;
        l)
            label="$OPTARG"
            ;;
        o)
            output_dir="$OPTARG"
            ;;
        s)
            ports+="$OPTARG "
            ;;
        :)
            echo "Option -$OPTARG requires an argument" >&2
            usage
            exit 1
            ;;
    esac
done

if [ -z "$*" ] ; then
    echo "No arguments passed"
    usage
    exit 1
fi

if [ "$dry_run" = "no" ] ; then
    if [ ! -x "$cl_img_select_bin" ] ; then
        echo "cl-img-select is not found on this system"
        exit 1
    fi

    if [ ! -x "$syseeprom_bin" ] ; then
        echo "decode-syseeprom is not found on this system"
        exit 1
    fi
fi


cl_ver=$(determine_cl_version)
eeprom=$(determine_eeprom_results)
mfg=$(determine_manufacturer "${eeprom}")
product=$(determine_product "${eeprom}")
service_tag=$(determine_service_tag "${eeprom}")
serial_num=$(determine_serial_num "${eeprom}")
results_dir=$(determine_output_dir "${output_dir}" "${cl_ver}" "${mfg}" "${product}")
create_output_dir "${results_dir}" "${verbose}" "${dry_run}"
dump_firmware "${results_dir}" "${eeprom}" "${verbose}" "${dry_run}"

for port in $ports ; do
    s_port=$(echo "$port" | cut -d : -f 1)
    s_part=$(echo "$port" | cut -d : -f 2)
    probe_port "${s_port}" "${results_dir}" "${label}" "${s_part}" "${verbose}" "${dry_run}"
done
