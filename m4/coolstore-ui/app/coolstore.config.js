var config =
{
  OCP_NAMESPACE: process.env.OPENSHIFT_BUILD_NAMESPACE,
  API_ENDPOINT: (process.env.COOLSTORE_GW_ENDPOINT != null ? process.env.COOLSTORE_GW_ENDPOINT  : process.env.COOLSTORE_GW_SERVICE + '-' + process.env.OPENSHIFT_BUILD_NAMESPACE),
  SECURE_API_ENDPOINT: (process.env.SECURE_COOLSTORE_GW_ENDPOINT != null ? process.env.SECURE_COOLSTORE_GW_ENDPOINT  : process.env.SECURE_COOLSTORE_GW_SERVICE + '-' + process.env.SECURE_COOLSTORE_GW_SERVICE),
  SSO_ENABLED: process.env.SSO_URL ? true : false,
  BASE_URL_PRODUCTS: (process.env.BASE_URL != null ? process.env.BASE_URL : ''),
  BASE_URL_ORDERS: (process.env.BASE_URL_ORDERS != null ? process.env.BASE_URL_ORDERS : '')
};

module.exports = config;
