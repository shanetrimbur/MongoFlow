# app.py - Python service with MongoDB Atlas integration
import os
import json
import logging
from typing import Dict, List, Any, Optional
from bson import ObjectId
import pymongo
from pymongo.errors import PyMongoError
from fastapi import FastAPI, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from mangum import Mangum

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize FastAPI app
app = FastAPI(
    title="MongoFlow Python Service",
    description="Python microservice with MongoDB Atlas integration",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For production, specify actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# MongoDB Atlas connection
MONGODB_URI = os.environ.get("MONGODB_URI")
DB_NAME = os.environ.get("DB_NAME", "mongoflow")
COLLECTION_NAME = os.environ.get("COLLECTION_NAME", "items")

# Lambda handler
handler = Mangum(app)

def lambda_handler(event, context):
    return handler(event, context)

# API Routes
@app.get("/")
async def root():
    return {"message": "MongoFlow Python Service is running", "status": "ok"}
