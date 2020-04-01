*===============================================================================
* FILE: pytree_p.ado
* PURPOSE: Enables post-estimation -predict- command to obtain fitted values
*   from pytree.ado (decision tree regression/classification with scikit-learn)
* SEE ALSO: pytree.ado
* AUTHOR: Michael Droste
*===============================================================================

program define pytree_p, eclass
	version 16.0
	syntax anything(id="argument name" name=arg) [if] [in], [pr xb]
	
	* Mark sample with if/in
	marksample touse, novarlist
	
	* Count number of variables
	local numVars : word count `arg'
	if `numVars'!=1 {
		di as error "Error: More than 1 prediction variable specified"
		exit 1
	}
	
	* Define locals prediction, features
	local predict_var "`arg'"
	local features "${features}"

	* Check to see if variable exists
	cap confirm new variable `predict_var'
	if _rc>0 {
		di as error "Error: prediction variable `predict_var' could not be created - probably already exists in dataset."
		di as error "Choose another name for the prediction."
		exit 1
	}
	
	* Generate an index variable for merging on obs number
	tempvar temp_index
	gen `temp_index' = _n
	tempfile t1
	qui save `t1'
	
	* Keep only if touse
	qui keep if `touse'==1
	
	* Also only keep joint nonmissing over features
	foreach v of varlist `features' {
		qui drop if mi(`v')
	}

	
	* Get predictions
	python: post_prediction("`features'","`predict_var'")
	
	* Keep only prediction and index
	keep `predict_var' `temp_index'
	tempfile t2
	qui save `t2'
	
	* Load original dataset, merge prediction on
	qui use `t1', clear
	qui merge 1:1 `temp_index' using `t2', nogen
	
	
end

python:

def post_prediction(vars, prediction):

	# Import things from namespace
	from __main__ import model_object as model

	# Load other requisite libraries
	from pandas import DataFrame
	from sklearn.tree import DecisionTreeClassifier,DecisionTreeRegressor
	from sfi import Data,Matrix
	
	# Load data into Pandas data frame
	df = DataFrame(Data.get(vars))
	colnames = []
	for var in vars.split():
		 colnames.append(var)
	df.columns = colnames
	
	# Create list of feature names
	features = df.columns[0:]
	
	# Generate predictions (on both training and test data)
	pred    = model.predict(df[features])
	
	# Export predictions back to Stata
   	Data.addVarFloat(prediction)
	Data.store(prediction,None,pred)
	
	
end