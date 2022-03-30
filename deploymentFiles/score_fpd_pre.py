import json
import joblib
import numpy as np
import pandas as pd
from azureml.core.model import Model

# Called when the service is loaded
def init():
    global model, missing_imputer, rare_imputer, target_encoder
    # Get the path to the registered model file and load it
    model_path = Model.get_model_path('xgb_model.pkl')
	missing_path = Model.get_model_path('missing_imputer.pkl')
	rare_path = Model.get_model_path('rare_imputer.pkl')
	target_path = Model.get_model_path('target_encoder.pkl')
    model = joblib.load(model_path)
	missing_imputer = joblib.load(missing_path)
	rare_imputer = joblib.load(rare_path)
	target_encoder = joblib.load(target_path)

# Called when a request is received
def run(raw_data, missing_imputer, rare_imputer, target_encoder):
    global data
    data = json.loads(raw_data)
    data = pd.DataFrame(data)
    data = pre_processing(data, missing_imputer, rare_imputer, target_encoder)
    # Get a prediction from the model
    predictions = model.predict(data)
    prob = model.predict_proba(data)
    score = prob[:,0]*1000
    # Return the predictions as any JSON serializable format
    return prob.tolist(), score.tolist()
	
	
def pre_processing(dataset, missing_imputer, rare_imputer, target_encoder):
    #Clean data
    dataset['BankName'] = dataset['BankName'].str.upper() 
    dataset['Email_Domain'] = dataset['Email_Domain'].str.upper() 

    list_i = []
    for i in dataset['BankName']:
        if type(i) == str:
            if 'CHAS' in i:
                i = 'CHASE'
            elif 'BANK OF AMERICA' in i or 'BANKOFAMERICA' in i or 'BANKOF AMERICA' in i:
                i = 'BANK OF AMERICA'
            elif 'WELLS FARGO' in i:
                i = 'WELLS FARGO'
            elif 'PNC' in i:
                i = 'PNC'
            elif 'WACHOVIA' in i:
                i = 'WACHOVIA'
            elif 'WOODFOREST' in i:
                i = 'WOODFOREST NATIONAL BANK'
            elif 'CITI' in i:
                i = 'CITI'
        else:
            i = i
        list_i.append(i)
    dataset['BankName'] = list_i
    

    # Treat missing value
    # for Pre_Status, mark missing as one category
    for var in ['AgeOfCustomer','BankName','Salary','Email_Domain','Monthsonjob','PayFrequency','FundedAmount','AccLen',\
                    'State','Affiliate','PTI']:
        dataset[var].fillna(missing_imputer[var], inplace = True)

#     print(dataset.info())
    
    # rare imputation
    cols = ['Affiliate', 'PayFrequency', 'State', 'BankName', 'Email_Domain']
    for col in cols:
        rare_imputation(col, rare_imputer, dataset, 'rare')

#     print(dataset[cols])

    # encode categorical
    for var in cols:
        dataset[var] = dataset[var].map(target_encoder[var])

    data['PTI'] = data['PTI'].astype(float, errors = 'ignore')


    train_vars = ['AgeOfCustomer','BankName','Salary','Email_Domain','Monthsonjob','PayFrequency','FundedAmount','AccLen',\
                    'State','Affiliate','PTI']
    dataset = dataset[train_vars]
    
    return dataset


def rare_imputation(variable, rare_imputer, dataset, which = 'rare'):    
    frequent_cat = rare_imputer[variable][0]
    # create new variables, with Rare labels imputed
    if which == 'frequent':
        # find the most frequent category
        mode_label = rare_imputer[variable][1]
        dataset[variable] = np.where(dataset[variable].isin(frequent_cat), dataset[variable], mode_label)
    else:
        dataset[variable] = np.where(dataset[variable].isin(frequent_cat), dataset[variable], 'rare')