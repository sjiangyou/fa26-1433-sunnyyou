The fa26-1433-sunnyyou repository is research-oriented code, so correctness and clarity are strongly prioritized over performance. The code is designed to be easy to read and understand, with clear documentation and comments throughout. In addition, the research done should be reproducible by simply running ```make all``` in the root directory.

Whenever implementing new features or making changes, ensure that both you (the agent) and the user (the human) have no ambiguity about what will be done, why it will be done, and how it will be done. This is crucial for maintaining the integrity of the research and ensuring that the results are reproducible. 

To do this, if there are any ambiguities that you cannot resolve, ask the user for clarification before proceeding. You should always give a summary of your understanding once all questions are resolved, including what you plan to do, why you plan to do it, and how you plan to do it. The user will confirm that the plan looks good with the phrase "OK". Only after receiving this confirmation should you proceed with the implementation.

During the implementation, continuously update the documentation and comments to reflect the new changes. It is paramount to keep the README's not only up to date, but also showing relevant information about the directory they are in. 

Style: Prefer functions over classes whenever possible, especially when creating repetitive code. Make sure that all indentations are 4 spaces always. The R language should be used when working on data setup, analysis, and plotting when possible. Use Python for model training, evaluation, deployment, and SHAP value analysis.

Information: Use the Current-Method.md and Important-Findings.md file to both reference and document any critical findings, insights, or conclusions that arise during the research process. Structure this file into sections that outline context (including previous work), data, methods, results, and conclusions.
