;+
; Generate geocoded results using GAMMA.
;
; First please run tli_hpa_1level;
; Then geocode.sh
; Then This scirpt works.
;
; Parameters:
;   workpath  : Work path containing both "HPA" and "geocode"
;
; Written by:
;   T.LI @ SWJTU, 20140709
;
PRO TLI_GEOCODING, workpath

  IF NOT TLI_HAVESEP(workpath) THEN workpath=workpath+PATH_SEP()
  hpapath=workpath+'HPA'+PATH_SEP()
  geocodepath=workpath+'geocode'+PATH_SEP()
  
  ; Input files.
  vdhfile=hpapath+'vdh' 
  plistfile=hpapath+'plistupdate_gamma'
  itabfile=workpath+'itab'
  sarlistfile=workpath+'SLC_tab'
  
  pdemfile=geocodepath+'phgt'
  vdh=TLI_READMYFILES(vdhfile, type='vdh')
  plist_gamma=LONG([vdh[1,*], vdh[2,*]])
  TLI_WRITE, plistfile, plist_gamma,/swap_endian
  
  IF NOT FILE_TEST(geocodepath,/DIRECTORY) THEN FILE_MKDIR, geocodepath
  
  ; Prepare & run the script
  hgtfile=FILE_SEARCH(workpath+'*.hgt')
  master_date=FILE_BASENAME(hgtfile,'.hgt')
  master_date=STRCOMPRESS(master_date[0],/REMOVE_ALL)
  scr="tli_geocode "+master_date
  CD, geocodepath
  Print, 'Running the script: geocode.sh. Please wait ...'
  SPAWN, scr
  
  pdem=TLI_READDATA(pdemfile, samples=1, format='float',/swap_endian)
  plist=TLI_READDATA(plistfile, format='LONG', samples=2, /swap_endian)
  
  ; Check the input data
  vdh_plist=COMPLEX(vdh[1, *], vdh[2, *])
  plist=COMPLEX(plist[0,*], plist[1, *])
  temp=TOTAL(ABS(vdh_plist-plist))
  
  IF temp NE 0 THEN Message, 'Error! Data in vdh and plist files are not consistent.'
  IF N_ELEMENTS(pdem) NE TLI_PNUMBER(plistfile) THEN Message, 'pdem and plist files are not consistent.'
  
  ; Add the dem error into pdem data.
  dh=vdh[4, *]
  dh_min=MIN(dh, max=dh_max)
  Case 1 OF
    0: BEGIN
      
      pdem_final=pdem
    END
    
    
    1: BEGIN
      delta=MODE(dh,nbins=100)
      dh=dh-delta[0]
;      dh=dh/cos(degree2radians(55))
      
      pdem_final=pdem+dh
      
      temp=MEAN(pdem_final)-3D * STDDEV(pdem_final)
      
      min_dem=MIN(temp, max=max_dem)
      pdem_final=pdem_final-min_dem
      
      pdem_final=pdem_final/COS(degree2radians(45D))
    END
    
  ENDCASE
  
  
  TLI_WRITE, pdemfile+'_final', FLOAT(pdem_final),/swap_endian
  
  CD, geocodepath
  scr1='rm -f pt_map_final pmap_final pmapll_final_orig plist_final.ll'
  scr2='pt2geo '+plistfile+' - '+workpath+'piece'+master_date+'.rslc.par - '+pdemfile+'_final'+' dem_seg.par '+master_date+'.diff_par 1 1 pt_map_final pmap_final plist_final.ll'
  
  SPAWN, scr1
  SPAWN, scr2
  
END