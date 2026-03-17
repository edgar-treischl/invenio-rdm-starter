#!/usr/bin/env python3
import os
from invenio_app.factory import create_api
from invenio_rdm_records.records.api import RDMRecord

app = create_api()
app.app_context().push()

def add_dataset(metadata, file_path=None):
    record = RDMRecord.create(metadata)
    record.commit()
    record.index()
    print(f"Created dataset: {metadata['title']}")
    if file_path and os.path.exists(file_path):
        bucket = record.files.bucket
        filename = os.path.basename(file_path)
        with open(file_path, "rb") as f:
            bucket.set_file(filename, f)
        record.commit()
        record.index()
        print(f"Uploaded file {filename} to {metadata['title']}")
    elif file_path:
        print(f"File not found: {file_path}")

# Public Iris dataset
iris_meta = {
    "title": "Iris Flower Dataset",
    "creators": [{"name": "Ronald A. Fisher"}],
    "description": "Classic Iris flower dataset for ML classification tasks.",
    "license": {"id": "cc-by-4.0"},
}
add_dataset(iris_meta, "/tmp/demo_data/iris.csv")

# Restricted Palmer Penguins dataset
penguins_meta = {
    "title": "Palmer Penguins Dataset",
    "creators": [{"name": "Allison Horst"}],
    "description": "Penguins dataset for ML and R examples.",
    "license": {"id": "cc-by-4.0"},
    "access": {"metadata_restricted": False, "files_restricted": True},
}
add_dataset(penguins_meta, "/tmp/demo_data/penguins.csv")
