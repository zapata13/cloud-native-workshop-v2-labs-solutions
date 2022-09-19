'use strict';

angular.module("app")

.factory('orders', ['$http', '$q', 'COOLSTORE_CONFIG', 'Auth', '$location', function($http, $q, COOLSTORE_CONFIG, $auth, $location) {
    var factory = {}, orders,baseUrl;

    if (COOLSTORE_CONFIG.BASE_URL_ORDERS.length === 0 ){
        baseUrl = $location.protocol() + '://order-' + COOLSTORE_CONFIG.OCP_NAMESPACE + '.' + $location.host().replace(/^.*?\.(.*)/g,"$1") + '/api/orders';
    }else{
        baseUrl = COOLSTORE_CONFIG.BASE_URL_ORDERS;
    }

    factory.getOrders = function() {

        var deferred = $q.defer();
		$http({
			   method: 'GET',
			   url: baseUrl
		   }).then(function(resp) {
				orders = resp.data;
			   	deferred.resolve(resp.data);
		   }, function(err) {
			   	deferred.reject(err);
		   });
		return deferred.promise;
    };

	return factory;

}]);
