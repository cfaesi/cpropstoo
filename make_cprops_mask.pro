pro make_cprops_mask $
   , infile = infile $
   , indata = cube $
   , outmask = mask $
   , outfile=outfile $   
   , rmsfile = rmsfile $
   , inrms = inrms $
;  CONDITIONS FOR THE MASK
   , prior = prior $
   , hi_thresh = hi_thresh $
   , hi_nchan = hi_nchan $
   , min_pix = min_pix $
   , min_area = min_area $   
;  EXTEND TO INCLUDE FAINTER ENVELOPES
   , lo_thresh = lo_thresh $
   , lo_nchan = lo_nchan $
;  DILATION
   , grow_xy = grow_xy $
   , grow_z = grow_z $
;  INVERT (USEFUL TO CHECK FALSE POSITIVES)
   , invert = invert

;+
;
; 
;
;-

  

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; READ IN THE DATA
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  if n_elements(infile) gt 0 then begin
     file_data = file_search(infile, count=file_ct)
     if file_ct eq 0 then begin
        message, "Data not found.", /info
        return
     endif else begin
        cube = readfits(file_data, hdr)
     endelse
  endif

  if n_elements(rmsfile) eq 0 then begin
     file_rms = file_search(rmsfile, count=file_ct)
     if file_ct eq 0 then begin
        message, "Noise not found.", /info
        return
     endif else begin
        rms = readfits(file_rms, mask_hdr)
     endelse
  endif

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; SET SOME DEFAULTS
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  if n_elements(rms) eq 0 then $
     rms = mad(cube)

  if n_elements(hi_thresh) eq 0 then $
     hi_thresh = 5.0

  if n_elements(hi_nchan) eq 0 then $
     hi_nchan = 2

  if n_elements(lo_thresh) eq 0 then $
     lo_thresh = hi_thresh

  if n_elements(lo_nchan) eq 0 then $
     lo_nchan = hi_nchan

  sz = size(cube)
  
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; CONVERT THE DATA TO A SIGNIFICANCE CUBE
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  rms_sz = size(rms)

; ... WE HAVE ONE NUMBER FOR THE RMS
  if rms_sz[0] eq 0 then $
     sig_cube = cube / rms

; ... WE HAVE AN RMS VECTOR (ASSUME Z)
  if rms_sz[0] eq 1 then begin
     sig_cube = cube
     for i = 0, sz[3]-1 do $
        sig_cube[*,*,i] = cube[*,*,i] / rms[i]
  endif

; ... WE HAVE AN RMS MAP (ASSUME X-Y)
  if rms_sz[0] eq 2 then begin
     sig_cube = cube
     for i = 0, sz[3]-1 do $
        sig_cube[*,*,i] = cube[*,*,i] / rms
  endif

; ... WE HAVE AN RMS CUBE
  if rms_sz[0] eq 3 then begin
     sig_cube = cube / rms
  endif

; ... IF DESIRED, INVERT THE CUBE
  if keyword_set(invert) then begin
     sig_cube *= -1.0
  endif

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; MAKE THE HIGH SIGNIFICANCE MASK
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
  
; IDENTIFY ALL REGIONS WHERE nchan CHANNELS ARE ABOVE sig SIGMA
  conj = sig_cube gt hi_thresh
  for i = 1, hi_nchan-1 do $
     conj *= shift(sig_cube gt hi_thresh,0,0,i)

; SET ALL OF THE PIXELS IN THESE REGIONS TO 1 IN THE MASK
  for i = 1, hi_nchan-1 do $
     conj += shift(conj, 0,0,-1*i)
  hi_mask = conj ge 1

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; MAKE THE LOW SIGNIFICANCE MASK
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
  
; IDENTIFY ALL REGIONS WHERE nchan CHANNELS ARE ABOVE sig SIGMA
  conj = sig_cube gt lo_thresh
  for i = 1, lo_nchan-1 do $
     conj *= shift(sig_cube gt lo_thresh,0,0,i)

; SET ALL OF THE PIXELS IN THESE REGIONS TO 1 IN THE MASK
  for i = 1, lo_nchan-1 do $
     conj += shift(conj, 0,0,-1*i)
  lo_mask = conj ge 1

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; PARE CONTIGUOUS REGIONS BY PIXELS OR AREA
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

; GET RID OF REGIONS SMALLER THAN A USER-SPECIFIED SIZE
  if n_elements(min_pix) gt 0 then begin
     reg = label_region(hi_mask)
     for i = 1, max(reg) do $
        if (total(reg eq i) lt min_pix) then $
           hi_mask[where(reg eq i)] = 0B     
  endif

  if n_elements(min_area) gt 0 then begin
     mask_2d = total(hi_mask,3) gt 0
     reg = label_region(mask_2d)
     for i = 1, max(reg) do $
        if (total(reg eq i) lt min_area) then $
           mask_2d[where(reg eq i)] = 0B     
     for i = 0, (size(cube))[3]-1 do $
        hi_mask[*,*,i] = hi_mask[*,*,i]*mask_2d
  endif
  
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; EXPAND THE HIGH SIGNIFICANCE CORE INTO THE LOW SIGNIFICANCE MASK
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  mask = grow_mask(hi_mask, constraint=lo_mask)

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
;  GROW THE FINAL MASK IN THE XY OR Z DIRECTIONS
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  if n_elements(grow_xy) gt 0 then begin
     for i = 0, sz[3]-1 do $
        mask[*,*,i] =  grow_mask(mask[*,*,i], rad=grow_xy, /quiet)
  endif
  
  if n_elements(grow_z) gt 0 then begin
     for i = 0, grow_z do $
        mask = mask or shift(mask,0,0,i) or shift(mask,0,0,-i)
  endif

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; APPLY A PRIOR, IF ONE IS SUPPLIED
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  if n_elements(prior) gt 0 then begin
     mask *= prior
  endif

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; RETURN THE MASK
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  if n_elements(outfile) gt 0 then begin
     sxaddpar, hdr, 'BUNIT', 'MASK'
     writefits, outfile, mask, hdr
  endif

end                             ; of make_cprops_mask