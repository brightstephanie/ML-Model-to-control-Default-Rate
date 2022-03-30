import json
import joblib
import numpy as np
import pandas as pd

def run(raw_data):
    # pass raw_data as string
    global data, missing_imputer, rare_imputer, target_encoder
    data = pd.DataFrame(raw_data)
    model = joblib.load('C:/Users/Minfei/OneDrive - The Strategic Group PR, LLC/Model Repositories/mfcx_pre_check_for_fpd/deploymentFiles/xgb_model.pkl')
    missing_imputer = joblib.load('C:/Users/Minfei/OneDrive - The Strategic Group PR, LLC/Model Repositories/mfcx_pre_check_for_fpd/deploymentFiles/missing_imputer.pkl')
    rare_imputer = joblib.load('C:/Users/Minfei/OneDrive - The Strategic Group PR, LLC/Model Repositories/mfcx_pre_check_for_fpd/deploymentFiles/rare_imputer.pkl')
    target_encoder = joblib.load('C:/Users/Minfei/OneDrive - The Strategic Group PR, LLC/Model Repositories/mfcx_pre_check_for_fpd/deploymentFiles/target_encoder.pkl')
#     data_f = data.copy
    data_fitting = pre_processing(data, missing_imputer, rare_imputer, target_encoder)
    predictions = model.predict(data_fitting)
    prob = model.predict_proba(data_fitting)
    score = prob[:, 0]*1000
#     # Return the predictions as any JSON serializable format
    data['Score'] = score
    data['Predicted'] = predictions
#     print('xgb_model test roc-auc: {}'.format(roc_auc_score(data.IfConvert, prob[:,1])))

    # Confusion Matrix
#     cm = confusion_matrix(data.IfConvert, predictions)
#     print(cm)
#     print('Precision: {}'.format(cm[1,1]/(cm[1,1] + cm[0,1])))
#     print('Recall: {}'.format(cm[1,1]/(cm[1,1] + cm[1,0])))
#     print('Accuracy: {}'.format(accuracy_score(data.IfConvert, predictions)))
    return data
	
	
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