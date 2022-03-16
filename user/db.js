const AWS = require("aws-sdk");

const TABLE_NAME = "users";

const dynamoDb = new AWS.DynamoDB.DocumentClient();

const dbFunctions = {
  put: (data) =>
    dynamoDb
      .put({
        TableName: TABLE_NAME,
        Item: data,
      })
      .promise(),

  get: (email) =>
    dynamoDb
      .get({
        TableName: TABLE_NAME,
        Key: {
          email,
        },
      })
      .promise(),
  getAll: () =>
    dynamoDb
      .scan({
        TableName: TABLE_NAME,
        Select: "ALL_ATTRIBUTES",
      })
      .promise(),
};

module.exports = {
  dbFunctions,
};
