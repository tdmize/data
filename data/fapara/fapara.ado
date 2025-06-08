
*! version 3.2 30jun10, pbe -- correct sample size error
*! version 3.1 8aug09, pbe  
*! version3.0  9apr07, pbe -- mata version
*! version 2.0  6apr07, pbe
*! version 1.1 15oct05, pbe
program define fapara
  version 9.2

  syntax [, seed(integer 0) pca reps(integer 1) *]
  if e(cmd)~="pca" & e(cmd)~="factor" {
    display as err "pca or factor not found"
    exit
  }
  capture drop __Eigen__ __PA__ __Factor__ __Dif__
  mat evmat = e(Ev)
  local ncols = colsof(evmat)
  
  local bign = e(N)
  local plural ""
  if `reps'>1 {
    local plural "s"
  }
  if "`pca'"=="" {
    local xtitle "Factor"
    local legend "Factor Analysis"
    local header "FA "
    local tstring "Factor Analysis"
  }
  if "`pca'"=="pca" { 
    local xtitle "Component"
    local legend "PCA"
    local header "PCA"
    local tstring "Principal Components"
  }
  
  mata: dopara(`reps', `seed', "`pca'", `bign')
  if strpos("`options'", "title")==0 {
    local options "title(Parallel Analysis)"
  }

  quietly gen __Factor__ = _n in 1/`ncols'
  display
  display in green "PA -- Parallel Analysis for `tstring' -- N = `bign'"
  display in green "PA Eigenvalues Averaged Over `reps' Replication`plural'"
  display "         `header'        PA          Dif"
  list __Eigen__ __PA__ __Dif__ in 1/`ncols', clean noheader

  twoway (connect __Eigen__ __Factor__)(line __PA__ __Factor__), ///
         scheme(s2mono) legend(label(1 `legend') label(2 "Parallel Analysis")) ///
             xtitle(`xtitle') ytitle("Eigenvalues") `options'
             
  drop __Factor__ __Eigen__ __PA__ __Dif__

end

version 9.2
mata:   
  void dopara(real scalar reps, real scalar seed, string scalar pca, real scalar bign)
  {
  evmat  = st_matrix("evmat")
 
  ncols  = cols(evmat)

  rowvec = range(1, ncols, 1)
  evtemp = J(1, ncols, 0)
  if (seed~=0) { 
    uniformseed(seed)
  }
  for (i=1; i<=reps; i++) { 
      x = uniform(bign, ncols)
      x = invnormal(x)
      c = correlation(x)
      if (pca=="") {
        c = c - invsym(diag(diagonal(invsym(c))))  /* replace diagonal with r-squared */
      }  
      ev = _symeigenvalues(c)
      evtemp = evtemp + ev
  }    
  evtemp = evtemp/reps
  dif    = evmat - evtemp
  outmat = (evmat \ evtemp \ dif)'
  (void) st_addvar("float", ("__Eigen__", "__PA__", "__Dif__"))
  st_store(rowvec, ("__Eigen__","__PA__","__Dif__"), outmat)
  }

end  
