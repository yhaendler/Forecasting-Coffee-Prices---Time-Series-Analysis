## function to find MAPE (Mean Absolute Percentage Error)
def mape(y_true, y_pred): 
    import numpy as np
    y_true, y_pred = np.array(y_true), np.array(y_pred)
    return np.mean(np.abs((y_true - y_pred) / y_true)) * 100


## function written by Joseph Nelson to print out the output of the Augmented Dickey-Fuller test
def interpret_dftest(dftest):
    import pandas as pd
    dfoutput = pd.Series(dftest[0:2], index=['Test Statistic','p-value'])
    return dfoutput


## function to gridsearch ARIMA hyperparameters
def gs_arima(train_df, d, n_p, n_q):
    
    from statsmodels.tsa.arima.model import ARIMA
    import pandas as pd

    # empty dictionary to fill in with info from the gridsearch
    results = {}
    results['model'] = []
    results['p'] = []
    results['d'] = []
    results['q'] = []
    results['AIC'] = []

    # Use nested for loop to iterate over values of p and q.
    for p in range(n_p): # over how many values of p we iterate

        for q in range(n_q): # over how many values of q we iterate

            # for certain combinations of p,d,q there are error messages;
            # to catch these errors, we run the model under try/except statements
            try:
                
                # print loop progress
                print(f'Fitting model: ARIMA({p}, {d}, {q})...')

                # Fitting an ARIMA(p, 0, q) model.
                results['model'].append(f'ARIMA({p}, {d} ,{q})')
                results['p'].append(p)
                results['d'].append(d)
                results['q'].append(q)

                # Instantiate ARIMA model.
                arima = ARIMA(endog = train_df.asfreq('D'), # the target variable
                              order = (p,d,q) )            

                # Fit ARIMA model.
                model = arima.fit(method_kwargs = {'maxiter':5000}) 

                results['AIC'].append(model.aic)
                
                # print loop progress
                print('... done')

            except:
                continue

    results_df = pd.DataFrame(results, columns=results.keys())
    return results_df


## function to plot train data, test data, and test predictions from ARIMA model
def plot_arima_data(train_df, test_df, test_preds, plot_title, x_label, y_label, arima_order):
    
    import matplotlib.pyplot as plt
    
    arima_fig = plt.figure(figsize=(10,6))

    # Plot training data.
    plt.plot(train.index, pd.DataFrame(train), color = 'tab:cyan', label='Training data')

    # Plot testing data.
    plt.plot(test.index, pd.DataFrame(test), color = 'tab:orange', label='Testing data')

    # Plot predicted test values.
    plt.plot(test.asfreq('D').index, test_preds, color = 'black', linewidth=3, label='Predicted')

    plt.legend(prop={'size':12}, bbox_to_anchor=(1,1))
    plt.title(label = plot_title, fontsize=16)
    plt.ylabel(y_label, fontsize=16)
    plt.xlabel(x_label, fontsize=16)
    plt.yticks(fontsize=14)
    plt.xticks(fontsize=14)
    
    plt.show();
    
    return arima_fig

    
## function to plot ARIMA results - zooming in on the test data
def plot_arima_data_zoomed(train_df, test_df, test_preds, plot_title, x_label, y_label, arima_order):
   
    import matplotlib.pyplot as plt
    
    # Plot data.
    arima_fig_zoomed = plt.figure(figsize=(10,6))

    # Plot training data.
    plt.plot(train.index, pd.DataFrame(train), color = 'tab:cyan', linewidth=3, label='Training data')

    # Plot testing data.
    plt.plot(test.index, pd.DataFrame(test), color = 'tab:orange', linewidth=3, label='Testing data')

    # Plot predicted test values.
    plt.plot(test.asfreq('D').index, test_preds, color = 'black', linewidth=3, label='Predicted')

    plt.xlabel(x_label, fontsize=16)
    plt.ylabel(y_label, fontsize=16)
    plt.xticks(fontsize=16)
    plt.yticks(fontsize=16)
    plt.legend(prop = {'size':16})

    plt.xlim(train.index[-20], test.index[-1]);
    plt.ylim(0.85, 2.1);

    plt.title(label = plot_title, fontsize=16);
    
    plt.show();
    
    return arima_fig_zoomed

    
## function to generate predictions for the test data of the RNN model
## code taken from: https://www.youtube.com/watch?v=S8tpSG6Q2H0
def generate_predictions(train, len_test, n_input, n_features, model):

    import numpy as np
    
    # empty list to be filled with predictions of the test set
    test_predictions = []
    
    # taking the last X days in the train data - this will give the first prediction for the testing set
    first_eval_batch = train[-n_input:]
    current_batch = first_eval_batch.reshape((1, n_input, n_features))
    
    # iterating for as long as the length of the test data set
    for i in range(len_test):
    
        # get the prediction for the first batch
        current_prediction = model.predict(current_batch)[0]

        # append the prediction to the test_predictions list
        test_predictions.append(current_prediction)

        # use the prediction to update the batch and remove the first value
        current_batch = np.append(current_batch[:,1:,:], [[current_prediction]], axis=1)
    
    return test_predictions


## function to plot the actual values vs the predictions for the test data set - RNN
def plot_test_predictions(test_df, x_label, y_label, plot_title):
    
    if 'value' not in test_df.columns and 'predictions' not in test_df.columns:
        return 'Error: test_df must contain a column named \'value\' and a column named \'predictions\'' 
    
    import matplotlib.pyplot as plt

    test_fig = plt.figure(figsize=(10,8))
    plt.plot(test_df['value'], linewidth=3, label='Actual price', color='tab:blue');
    plt.plot(test_df['predictions'], linewidth=3, label='Predicted price', color='tab:orange');
    plt.legend(prop = {'size':16})
    plt.xticks(fontsize=16)
    plt.yticks(fontsize=16);
    plt.xlabel(x_label, fontsize=16);
    plt.ylabel(y_label, fontsize=16)
    plt.title(plot_title, fontsize=16);
    plt.tight_layout();
    plt.show();
    
    return test_fig