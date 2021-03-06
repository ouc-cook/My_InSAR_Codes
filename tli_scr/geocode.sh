#!/bin/bash
##################################################################
###   geocode.sh: Geocoding for PS points.  ###
###         using:                                             ###
###         - DEM file
###         
###         - PS intermedia files.
##################################################################
###   History:
###     20120224: Written by T.LI @ CUHK.
###     20140821: Re-organized by T.LI @ Sasmac.
##################################################################
echo ""
echo "*** geocode.sh geocode for PS points."
echo ""
echo "    Required data:"
echo "       - DEM file. (with reference to construct_dem_tli.sh)"
echo "       - PS intermedia files."
echo ""

if [ $# -lt 1 ]; then
  echo ""
  echo "Usage: geocode.sh <master_date> [dem] [slc_path] [ipta_path] [plist] [pmask] [phgt]"
  echo ""
  echo "Input parameters:"
  echo ""
  echo "  master_date       : Date of the master image (yyyymmdd)."
  echo "  dem               : (input) DEM file (enter - for default: use ipta intermedia files)."
  echo "  slc_path          : Path containing all the slc pieces. (enter - for default: ../piece)"
  echo "  ipta_path         : IPTA work directory (enter - for default: ../)."
  echo "  plist             : (input) Point list file. (enter - for default: ../HPA/plistupdate_gamma)"
  echo "  pmask             : (input) Point data stack of mask values ( byte, set - to accept all points)"
  echo "  phgt              : (output) Point data stack of height values ( Float, enter - for default: phgt)"
  exit
fi

# Assignment
master_date=$1

dem_flag=0
if [ $# -ge 2 ]; then 
  if [ $2 != "-" ]; then 
    dem_flag=1
    dem=$2
  fi
fi

slc_path="../piece"
if [ $# -ge 3 ]; then
  if [ $3 !- "-" ]; then slc_path=$3; fi
fi

ipta_path="../"
if [ $# -ge 4 ]; then
  if [ $4 !="-" ]; then ipta_path=$3; fi
fi

plist="../HPA/plistupdate_gamma"
if [ $# -ge 5 ]; then
  if [ $5 != "-" ]; then $plist=$5; fi
fi

pmask="-"
if [ $# -ge 6 ]; then pmask=$6; fi

phgt="phgt"
if [ $# -ge 7 ]; then 
  if [ $7 !- "-" ]; then phgt=$7; fi
fi

# Pre defined parameters.
masterpwr=$slc_path/$master_date.rslc.pwr
mslc_par=$slc_path/$master_date.rslc.par
width=$(awk '$1 == "range_samples:" {print $2}' $mslc_par)
line=$(awk '$1 == "azimuth_lines:" {print $2}' $mslc_par)
type=0
format=$(awk '$1 == "image_format:" {print $2}' $mslc_par)
if [ "$format"=="SCOMPLEX" ]
then
	type=1
fi

ras_pt $plist - ../ave.ras pt_ave.ras 1 1 0 255 0 10

# Step 1, geocoding for the images.
if [ $dem_flag == 1 ] 
then
  gc_map $masterpwr.par - $dem.par $dem dem_seg.par dem_seg lookup 50 50 sim_sar  # Use disdem_par to check dem_seg.
  # *** sim_sar 的坐标系是DEM坐标系 ***
  # *** lookup table 应该是与sim_sar大小一致的，与dem_seg大小也一致 ***
  # *** 每个点上的数对应sim_sar的像素在slc中的坐标 ***

  echo -ne "$M_P-$S_P\n 0 0\n 32 32\n 64 64\n 7.0\n 0\n\n" > create_diffpar
  create_diff_par $masterpwr.par - $master_date.diff_par 1 <create_diffpar
  rm -f create_diffpar
  offset_pwrm sim_sar ../ave.pwr $master_date.diff_par $master_date.offs $master_date.snr - - offsets 2
  offset_fitm $master_date.offs $master_date.snr $master_date.diff_par coffs coffsets - -
  offset_pwrm sim_sar ../ave.pwr $master_date.diff_par $master_date.offs $master_date.snr - - offsets 4 40 40 -  
  width_dem=$(awk '$1 == "width:" {print $2}' dem_seg.par)
  width_mli=$(awk '$1 == "range_samples:" {print $2}' $mslc_par)
  line_mli=$(awk '$1 == "azimuth_lines:" {print $2}' $mslc_par)

  gc_map_fine lookup $width_dem $master_date.diff_par lookup_fine 1 #Fine look up table  使用偏移量参数改进lookup table

  geocode_back ../ave.pwr $width_mli lookup_fine ave.utm.rmli $width_dem - 3 0  #Geocoded pwr
  raspwr ave.utm.rmli $width_dem - - - - - - - ave.utm.rmli.ras 
  nlines_map=$(awk '$1 == "nlines:" {print $2}' dem_seg.par)
  geocode lookup_fine sim_sar $width_dem sim_sar.rdc $width_mli $line_mli 2 0
  geocode lookup_fine dem_seg $width_dem $master_date.hgt $width - 1 0
  raspwr $master_date.hgt $width_mli 1 0 1 1 1. .35 1 $master_date.hgt.ras
else
  cp ../$master_date.hgt ../ave.utm.rmli.ras ../dem_seg.par ../$master_date.diff_par .
fi

# Step 2, geocoding for the PS points.
npt $plist >numberp
np=$(awk '$1 == "total_number_of_points:" {print $2}' numberp)
rm -f numberp
rm -f $phgt
d2pt $master_date.hgt $width $plist 1 1 $phgt $np 2
rm -f pt_map pmap pmapll_orig `basename $plist`.ll
pt2geo $plist $pmask $mslc_par - $phgt dem_seg.par $master_date.diff_par 1 1 pt_map pmap `basename $plist`.ll #推测此处应该没有错误，因为点位分布与Google earth相似。
ras_pt pt_map - ave.utm.rmli.ras pt.utm.ras 1 1 0 255 0 10
