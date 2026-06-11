"""
Reference FastAPI app that demonstrates the secret + storage access pattern
expected by the Terraform deployment in this repo.

Authentication is handled entirely by the user-assigned managed identity
attached to the Container App — no connection strings or account keys.
"""

import os
from azure.identity import ManagedIdentityCredential
from azure.keyvault.secrets import SecretClient
from azure.storage.blob import BlobServiceClient
from fastapi import FastAPI, HTTPException, UploadFile

# Client ID of the user-assigned MI (injected by Terraform as env var).
CLIENT_ID = os.environ["AZURE_CLIENT_ID"]
STORAGE_ACCOUNT = os.environ["STORAGE_ACCOUNT_NAME"]
STORAGE_CONTAINER = os.environ["STORAGE_CONTAINER_NAME"]
KEY_VAULT_URI = os.environ["KEY_VAULT_URI"]

credential = ManagedIdentityCredential(client_id=CLIENT_ID)

blob_service = BlobServiceClient(
    account_url=f"https://{STORAGE_ACCOUNT}.blob.core.windows.net",
    credential=credential,
)
container_client = blob_service.get_container_client(STORAGE_CONTAINER)

secrets = SecretClient(vault_url=KEY_VAULT_URI, credential=credential)

app = FastAPI(title="FastAPI on Azure (Private)")


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/secret/{name}")
def read_secret(name: str) -> dict:
    try:
        return {"name": name, "value": secrets.get_secret(name).value}
    except Exception as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@app.post("/media")
async def upload_media(file: UploadFile) -> dict:
    blob = container_client.get_blob_client(file.filename)
    blob.upload_blob(await file.read(), overwrite=True)
    return {"blob": file.filename, "size": blob.get_blob_properties().size}


@app.get("/media")
def list_media() -> dict:
    return {"items": [b.name for b in container_client.list_blobs()]}
