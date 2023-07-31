#!/bin/bash


echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "3 Peer Application Script."
echo

CHANNEL_NAME="mychannel"
DELAY="$2"
: ${CHANNEL_NAME:="mychannel"}
: ${TIMEOUT:="1500"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem


echo "Channel name : "$CHANNEL_NAME

# verify the result of the end-to-end test
verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "Trace "$2" "
    echo "ERROR - FAILED to execute 3 Peer End to End Application."
		echo
   		exit 1
	fi
}

setGlobals () {

	if [ $1 -eq 0 ] ; then
		CORE_PEER_LOCALMSPID="Org1MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
		CORE_PEER_ADDRESS=peer0.org1.example.com:7051
        CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.crt
		CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.key
	elif [ $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="Org2MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
		CORE_PEER_ADDRESS=peer0.org2.example.com:7051
		CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.crt
		CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.key
	elif [ $1 -eq 2 ] ; then
		CORE_PEER_LOCALMSPID="Org3MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
		CORE_PEER_ADDRESS=peer0.org3.example.com:7051
        CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.crt
        CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.key
	fi		
 
	env |grep CORE
} 

createChannel() {
	setGlobals 0

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx >&channellog.txt
	else
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&channellog.txt
	fi
	res=$?
	cat channellog.txt
	verifyResult $res "Channel creation failed"
	echo " ========================= Channel \"$CHANNEL_NAME\" is created successfully. ================================="
	echo
	echo
}



joinWithRetry () {
	peer channel join -b $CHANNEL_NAME.block  >&retrylog.txt
	res=$?
	cat retrylog.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep $DELAY
		joinWithRetry $1
	else
		COUNTER=1
	fi
  verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
	for ch in 0 1 2 ; do
		setGlobals $ch
		joinWithRetry $ch
		echo "PEER$ch joined on the channel \"$CHANNEL_NAME\"."
		sleep $DELAY
		echo
	done
}

installChaincode () {
	PEER=$1
	setGlobals $PEER
	peer chaincode install -n samplecc -v 1.0 -p github.com/ >&installlog.txt
	res=$?
	cat installlog.txt
        verifyResult $res "Chaincode installation on remote peer PEER$PEER has failed."
	echo "===========================Chaincode is installed on remote peer PEER $PEER.============================"
	echo
}

instantiateChaincode () {
	PEER=$1
	setGlobals $PEER
	echo "**************************************Chaincode instantiation on PEER$PEER****************************************"
	echo $CORE_PEER_LOCALMSPID
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o orderer.example.com:7050 -C $CHANNEL_NAME -n samplecc -v 1.0 -c '{"Args":[""]}' -P " OR('Org1MSP.member','Org2MSP.member')" >&instantiatelog.txt
	else
		peer chaincode instantiate -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CONTRACT -v 1.0 -c '{"Args":[""]}' -P " OR('Org1MSP.member','Org2MSP.member')" >&instantiatelog.txt
	fi
	res=$?
	cat instantiatelog.txt
	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed."
	echo "===========================Chaincode Instantiation on PEER $PEER on channel '$CHANNEL_NAME' is successful. ========================"
	echo
}


#iptables -F
echo "Creating channel."
createChannel

echo "Peers joining the channel."
joinChannel
echo "===========================Installing chaincode on Org1/peer0."
installChaincode 0
echo "-------------------------Installing chaincode on Org2/peer0."
installChaincode 1
echo "----------------------Install chaincode on Org3/peer0."
installChaincode 2


#Instantiate chaincode in one of the peers
echo "=========================================Instantiating chaincode on ====================="
instantiateChaincode 0
echo
sleep 5
