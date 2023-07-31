# Hyperledger Fabric network setup with 3 Peer and 1 Orderer and a sample chaincode  

Pre Requisite - Hyperledger Binaries and HLF Pre-Requisites software are installed

# Following are the steps to run the setup
1. create a working folder, change directory to working folder
2. git clone https://github.com/samanipour/HyperLedger_3PeerNetwork.git
3. sudo chmod -R 755 sample_3PeerNetwork/
4. cd HyperLedger_3PeerNetwork  
5. mkdir config  
	<remove config and crypto-config if they are existing before creation of config folder (Optional)>
	5a. sudo rm -rf config
	5b  sudo rm -rf crypto-config
6. export COMPOSE_PROJECT_NAME=net
7. sudo ./generate.sh
8. sudo ./start.sh
9. docker exec -it cli /bin/bash
10. peer chaincode invoke -C mychannel -n samplecc -c '{"function":"initCar","Args":["Ali","Blue","BMW"]}'
11. peer chaincode query -C mychannel -n samplecc -c '{"function":"readCar","Args":["Ali"]}'      

>> returns {"color":"bmw","docType":"Car","model":"blue","owner":"Ali"}

12. docker exec -e "CORE_PEER_ADDRESS=peer0.org2.example.com:7051" -e "CORE_PEER_LOCALMSPID=Org2MSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" cli peer chaincode query -C mychannel -n samplecc -c '{"function":"readCar","Args":["Ali"]}'      

>> returns {"color":"bmw","docType":"Car","model":"blue","owner":"Ali"}

13. docker ps

you should see 2 chaincode container one for Org1 and Org2 each
