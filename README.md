# README #

Model training file - in Jupyternotebook

Folders
- data: 
ForTraining: customer data used for model fitting
ForQA: applicant data used for QA

- environment: 
Files to create conda environment with needed libraries
Prerrequisite: Have Anaconda installed
Steps:
1. Run createEnv.bat to create and activate the file.
2. Once the environment is created and there is no errors, open Anaconda Navigator, select MPD-precheck-fpd environment.
3. Installed Spyder if needed.

- localRun
Files to run the model locally. Scoring code file(.py) and Pkl files.

- deploymentFiles
Files used to deploy the model on Cloud service. Scoring code file(.py) and pkl files.
