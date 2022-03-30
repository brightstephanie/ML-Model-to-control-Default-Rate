from azureml.core.conda_dependencies import CondaDependencies

# Add the dependencies for your model
myenv = CondaDependencies()
myenv.add_pip_package("scikit-learn==0.21.3")
myenv.add_pip_package("numpy==1.16.5")
myenv.add_pip_package("pandas==0.25.1")
myenv.add_pip_package("joblib==0.13.2")
myenv.add_pip_package("xgboost==0.90")
myenv.add_conda_package("json")


# Save the environment config as a .yml file
env_file = 'service_files/env.yml'
with open(env_file,"w") as f:
    f.write(myenv.serialize_to_string())
print("Saved dependency info in", env_file)