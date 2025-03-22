#!/bin/bash

# Directory where the virtual environment will be created
VENV_DIR="venv"

# Check if the virtual environment directory exists
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    
    # Activate the virtual environment
    source "$VENV_DIR/bin/activate"

    # Install requirements
    echo "Updating pip..."
    python -m pip install --upgrade pip
    echo "Installing requirements from requirements.txt..."
    pip install -r requirements.txt

    # Deactivate the virtual environment
    deactivate

    echo "Virtual environment created and requirements installed."
else
    echo "Virtual environment already exists."
fi

echo "Run 'source $VENV_DIR/bin/activate' to activate the virtual environment."
