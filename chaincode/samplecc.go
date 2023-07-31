package main

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	pb "github.com/hyperledger/fabric/protos/peer"
)

// SampleChaincode example sample Chaincode implementation
type SampleChaincode struct {
}

type car struct {
	ObjectType string `json:"docType"` //docType is used to distinguish the various types of objects in state database
	Owner      string `json:"owner"`    //the fieldtags are needed to keep case from bouncing around
	Color      string `json:"color"`
	Model      string `json:"model"`
	
}

// ===================================================================================
// Main
// ===================================================================================
func main() {
	err := shim.Start(new(SampleChaincode))
	if err != nil {
		fmt.Printf("Error starting Sample chaincode: %s", err)
	}
}

// Init initializes chaincode
// ===========================
func (t *SampleChaincode) Init(stub shim.ChaincodeStubInterface) pb.Response {
	return shim.Success(nil)
}

// Invoke - Our entry point for Invocations
// ========================================
func (t *SampleChaincode) Invoke(stub shim.ChaincodeStubInterface) pb.Response {
	function, args := stub.GetFunctionAndParameters()
	fmt.Println("invoke is running " + function)

	// Handle different functions
	if function == "initCar" { //create a new car
		return t.initCar(stub, args)
	} else if function == "transferCar" { //change owner of a specific car
		return t.transferCar(stub, args)
	} else if function == "delete" { //delete a car
		return t.delete(stub, args)
	} else if function == "readCar" { //read a car
		return t.readCar(stub, args)
	
	}

	fmt.Println("invoke did not find func: " + function) //error
	return shim.Error("Received unknown function invocation")
}

// ============================================================
// initCar - create a new car, store into chaincode state
// ============================================================
func (t *SampleChaincode) initCar(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	var err error

	//   0       1       2     
	// "Ali", "Blue", "BMW"
	if len(args) != 3 {
		return shim.Error("Incorrect number of arguments. Expecting 4")
	}

	// ==== Input sanitation ====
	fmt.Println("- start init car")
	if len(args[0]) <= 0 {
		return shim.Error("1st argument must be a non-empty string")
	}
	if len(args[1]) <= 0 {
		return shim.Error("2nd argument must be a non-empty string")
	}
	if len(args[2]) <= 0 {
		return shim.Error("3rd argument must be a non-empty string")
	}
	
	owner := args[0]
	color := strings.ToLower(args[1])
	model := strings.ToLower(args[2])
	

	// ==== Check if car already exists ====
	carAsBytes, err := stub.GetState(owner)
	if err != nil {
		return shim.Error("Failed to get car: " + err.Error())
	} else if carAsBytes != nil {
		fmt.Println("This car already exists for owner: " + owner)
		return shim.Error("This car already exists: " + owner)
	}

	// ==== Create car object and marshal to JSON ====
	objectType := "Car"
	car := &car{objectType, owner, color, model}
	carJSONasBytes, err := json.Marshal(car)
	if err != nil {
		return shim.Error(err.Error())
	}
	//Alternatively, build the car json string manually if you don't want to use struct marshalling
	//carJSONasString := `{"docType":"Car",  "owner": "` + owner + `", "color": "` + color + `", "model": ` + model + `"}`
	//carJSONasBytes := []byte(carJSONasString)

	// === Save car to state ===
	err = stub.PutState(owner, carJSONasBytes)
	if err != nil {
		return shim.Error(err.Error())
	}


	// ==== Car saved. Return success ====
	fmt.Println("- end init car")
	return shim.Success(nil)
}

// ===============================================
// readCar - read a car from chaincode state
// ===============================================
func (t *SampleChaincode) readCar(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	var name, jsonResp string
	var err error

	if len(args) != 1 {
		return shim.Error("Incorrect number of arguments. Expecting name of the owner to query")
	}

	name = args[0]
	valAsbytes, err := stub.GetState(name) //get the car from chaincode state
	if err != nil {
		jsonResp = "{\"Error\":\"Failed to get state for " + name + "\"}"
		return shim.Error(jsonResp)
	} else if valAsbytes == nil {
		jsonResp = "{\"Error\":\"Car does not exist for owner: " + name + "\"}"
		return shim.Error(jsonResp)
	}

	return shim.Success(valAsbytes)
}

// ==================================================
// delete - remove a car key/value pair from state
// ==================================================
func (t *SampleChaincode) delete(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	var jsonResp string
	var carJSON car
	if len(args) != 1 {
		return shim.Error("Incorrect number of arguments. Expecting 1")
	}
	owner := args[0]

	
	valAsbytes, err := stub.GetState(owner) //get the ownerName from chaincode state
	if err != nil {
		jsonResp = "{\"Error\":\"Failed to get state for " + owner + "\"}"
		return shim.Error(jsonResp)
	} else if valAsbytes == nil {
		jsonResp = "{\"Error\":\"Car does not exist for owner: " + owner + "\"}"
		return shim.Error(jsonResp)
	}

	err = json.Unmarshal([]byte(valAsbytes), &carJSON)
	if err != nil {
		jsonResp = "{\"Error\":\"Failed to decode JSON of car: " + owner + "\"}"
		return shim.Error(jsonResp)
	}

	err = stub.DelState(owner) //remove the car from chaincode state
	if err != nil {
		return shim.Error("Failed to delete state:" + err.Error())
	}


	return shim.Success(nil)
}

// ===========================================================
// transfer a car by setting a new owner name on the car
// ===========================================================
func (t *SampleChaincode) transferCar(stub shim.ChaincodeStubInterface, args []string) pb.Response {

	//   0       1
	// "name", "bob"
	if len(args) < 2 {
		return shim.Error("Incorrect number of arguments. Expecting 2")
	}

	owner := args[0]
	newOwner := strings.ToLower(args[1])
	fmt.Println("- start transferCar ", owner, newOwner)

	carAsBytes, err := stub.GetState(owner)
	if err != nil {
		return shim.Error("Failed to get car:" + err.Error())
	} else if carAsBytes == nil {
		return shim.Error("Car does not exist")
	}

	carToTransfer := car{}
	err = json.Unmarshal(carAsBytes, &carToTransfer) //unmarshal it aka JSON.parse()
	if err != nil {
		return shim.Error(err.Error())
	}
	carToTransfer.Owner = newOwner //change the owner

	carJSONasBytes, _ := json.Marshal(carToTransfer)
	err = stub.PutState(owner, carJSONasBytes) //rewrite the car
	if err != nil {
		return shim.Error(err.Error())
	}

	fmt.Println("- end transferCar (success)")
	return shim.Success(nil)
}


