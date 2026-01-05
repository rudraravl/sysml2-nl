package OdonDeviceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def LengthValue :> ISQ::LengthValue;
    attribute def VolumeFlowRateValue :> ISQ::VolumeFlowRateValue;
    
    enum def DeviceState {
        idle;
        positioning;
        inflating;
        gripping;
        applyingTraction;
        deflating;
        removing;
        complete;
    }
    
    enum def GripQuality {
        none;
        partial;
        secure;
        excessive;
    }
    
    item def FetalHead {
        attribute circumference : LengthValue;
        attribute position : LengthValue;
        attribute station : Real;
    }
    
    item def BirthCanal {
        attribute diameter : LengthValue;
    }
    
    item def AirSupply;
    
    port def AirPort {
        attribute pressure : PressureValue;
        attribute flowRate : VolumeFlowRateValue;
    }
    
    port def TractionPort {
        attribute force : ForceValue;
        attribute angle : Real;
    }
    
    port def SensorPort {
        attribute measuredPressure : PressureValue;
        attribute measuredForce : ForceValue;
    }
    
    part def AirPump {
        attribute maxPressure : PressureValue;
        attribute currentFlowRate : VolumeFlowRateValue;
        port outlet : AirPort;
        
        action def SupplyAir {
            in targetPressure : PressureValue;
            out actualPressure : PressureValue;
        }
    }
    
    part def PressureRegulator {
        attribute setPoint : PressureValue;
        port inlet : AirPort;
        port outlet : AirPort;
        
        action def RegulateFlow {
            in desiredPressure : PressureValue;
            out regulatedPressure : PressureValue;
        }
    }
    
    part def SafetyValve {
        attribute releaseThreshold : PressureValue;
        port inlet : AirPort;
        port vent : AirPort;
        
        assert constraint safetyLimit {
            inlet.pressure <= releaseThreshold
        }
    }
    
    part def InflatableSleeve {
        attribute innerDiameter : LengthValue;
        attribute outerDiameter : LengthValue;
        attribute currentPressure : PressureValue;
        attribute gripQuality : GripQuality;
        port airInlet : AirPort;
        
        action def Inflate {
            in targetPressure : PressureValue;
            out gripAchieved : GripQuality;
        }
        
        action def Deflate {
            out deflationComplete : Boolean;
        }
    }
    
    part def RigidCup {
        attribute diameter : LengthValue;
        attribute material : String;
        part sleeve : InflatableSleeve;
    }
    
    part def TractionHandle {
        attribute appliedForce : ForceValue;
        attribute tractionAngle : Real;
        port grip : TractionPort;
    }
    
    part def PressureSensor {
        attribute reading : PressureValue;
        port sense : SensorPort;
    }
    
    part def ForceSensor {
        attribute reading : ForceValue;
        port sense : SensorPort;
    }
    
    part def ControlUnit {
        attribute currentState : DeviceState;
        port sensorInput : SensorPort;
        
        action def MonitorSafety {
            in pressureReading : PressureValue;
            in forceReading : ForceValue;
            out safetyStatus : Boolean;
        }
    }
    
    action def PositionDevice {
        in fetalHead : FetalHead;
        in birthCanal : BirthCanal;
        out positioned : Boolean;
    }
    
    action def InflateCuff {
        in targetPressure : PressureValue;
        out inflationComplete : Boolean;
        out gripQuality : GripQuality;
    }
    
    action def ApplyTraction {
        in tractionForce : ForceValue;
        in tractionAngle : Real;
        out fetalDescent : LengthValue;
    }
    
    action def MonitorProgress {
        in fetalPos : LengthValue;
        in cuffPressure : PressureValue;
        in appliedForce : ForceValue;
        out continueDelivery : Boolean;
    }
    
    action def DeflateCuff {
        out deflationComplete : Boolean;
    }
    
    action def RemoveDevice {
        out removalComplete : Boolean;
    }
    
    action def AssistedDeliveryProcedure {
        first start;
        then action position : PositionDevice {
            in fetalHead;
            in birthCanal;
            out devicePositioned : Boolean;
        }
        then action inflate : InflateCuff {
            in targetPressure = 50.0;
            out inflationComplete : Boolean;
            out gripQuality : GripQuality;
        }
        then merge tractionCycle;
        then action monitor : MonitorProgress {
            in fetalPos;
            in cuffPressure = inflate.targetPressure;
            in appliedForce;
            out continueDelivery : Boolean;
        }
        then decide;
            if monitor.continueDelivery and monitor.fetalPos < 0.0 then applyTraction;
            if monitor.fetalPos >= 0.0 then deflate;
        action applyTraction : ApplyTraction {
            in tractionForce = 120.0;
            in tractionAngle = 45.0;
            out fetalDescent : LengthValue;
        }
        then tractionCycle;
        action deflate : DeflateCuff {
            out deflationComplete : Boolean;
        }
        then action remove : RemoveDevice {
            out removalComplete : Boolean;
        }
        then done;
    }
    
    state def OdonDeviceStateMachine {
        entry; then idle;
        
        state idle;
        
        transition idle_to_positioning
            first idle
            accept PositioningCommand
            then positioning;
        
        state positioning;
        
        transition positioning_to_inflating
            first positioning
            accept PositionConfirmed
            then inflating;
        
        state inflating;
        
        transition inflating_to_gripping
            first inflating
            accept InflationComplete
            then gripping;
        
        state gripping;
        
        transition gripping_to_applyingTraction
            first gripping
            accept TractionCommand
            then applyingTraction;
        
        state applyingTraction;
        
        transition applyingTraction_to_deflating
            first applyingTraction
            accept DeliveryComplete
            then deflating;
        
        transition applyingTraction_to_gripping
            first applyingTraction
            accept PauseCommand
            then gripping;
        
        state deflating;
        
        transition deflating_to_removing
            first deflating
            accept DeflationComplete
            then removing;
        
        state removing;
        
        transition removing_to_complete
            first removing
            accept RemovalComplete
            then complete;
        
        state complete;
    }
    
    part def OdonDevice {
        attribute deviceState : DeviceState;
        attribute operatingPressure : PressureValue;
        attribute maxTractionForce : ForceValue;
        attribute procedureDuration : TimeValue;
        
        part rigidCup : RigidCup {
            attribute :>> diameter = 120.0;
            attribute :>> material = "medical_grade_plastic";
            
            part :>> sleeve {
                attribute :>> innerDiameter = 100.0;
                attribute :>> outerDiameter = 120.0;
            }
        }
        
        part airPump : AirPump {
            attribute :>> maxPressure = 80.0;
            attribute :>> currentFlowRate = 2.0;
        }
        
        part regulator : PressureRegulator {
            attribute :>> setPoint = 50.0;
        }
        
        part safetyValve : SafetyValve {
            attribute :>> releaseThreshold = 60.0;
        }
        
        part pressureSensor : PressureSensor {
            attribute :>> reading : PressureValue;
        }
        
        part forceSensor : ForceSensor {
            attribute :>> reading : ForceValue;
        }
        
        part tractionHandle : TractionHandle {
            attribute :>> appliedForce : ForceValue;
            attribute :>> tractionAngle = 45.0;
        }
        
        part controlUnit : ControlUnit {
            attribute :>> currentState = DeviceState::idle;
        }
        
        connection airSupplyPath connect airPump.outlet to regulator.inlet;
        connection regulatedAirPath connect regulator.outlet to rigidCup.sleeve.airInlet;
        connection safetyPath connect regulator.outlet to safetyValve.inlet;
        connection pressureMonitoring connect rigidCup.sleeve.airInlet to pressureSensor.sense;
        connection forceMonitoring connect tractionHandle.grip to forceSensor.sense;
        connection sensorFeedback1 connect pressureSensor.sense to controlUnit.sensorInput;
        connection sensorFeedback2 connect forceSensor.sense to controlUnit.sensorInput;
        
        perform action deliveryProcedure : AssistedDeliveryProcedure;
        
        exhibit state deviceBehavior : OdonDeviceStateMachine;
    }
    
    requirement <'REQ-OD-001'> primaryFunction {
        doc /* The Odon Device shall assist in vaginal delivery by providing 
             * controlled traction on the fetal head through an inflatable sleeve 
             * mechanism that creates a secure, atraumatic grip around the fetal 
             * head, enabling safe extraction during the second stage of labor.
             */
        subject odonDevice : OdonDevice;
    }
    
    requirement <'REQ-OD-002'> pressureControl {
        doc /* The device shall maintain inflation pressure between 40 kPa and 
             * 60 kPa to ensure secure grip without excessive compression that 
             * could cause injury.
             */
        subject device : OdonDevice;
        assert constraint {
            device.operatingPressure >= 40.0 and 
            device.operatingPressure <= 60.0
        }
    }
    
    requirement <'REQ-OD-003'> tractionLimit {
        doc /* The maximum traction force applied shall not exceed 150 N to 
             * prevent injury to the mother or infant during delivery assistance.
             */
        subject device : OdonDevice;
        assert constraint {
            device.maxTractionForce <= 150.0
        }
    }
    
    requirement <'REQ-OD-004'> cupDimension {
        doc /* The rigid cup diameter shall be 120 mm to accommodate the average 
             * fetal head circumference and ensure proper fit within the birth canal.
             */
        subject cup : OdonDevice::rigidCup;
        assert constraint {
            cup.diameter == 120.0
        }
    }
    
    requirement <'REQ-OD-005'> procedureTime {
        doc /* The device shall complete the assisted delivery procedure within 
             * 180 seconds to minimize maternal and fetal stress.
             */
        subject device : OdonDevice;
        assert constraint {
            device.procedureDuration <= 180.0
        }
    }
    
    requirement <'REQ-OD-006'> safetyMonitoring {
        doc /* The device shall continuously monitor pressure and force parameters 
             * and automatically release if safety thresholds are exceeded.
             */
        subject device : OdonDevice;
        require constraint {
            device.safetyValve.releaseThreshold == 60.0
        }
    }
    
    part odonDeviceSystem : OdonDevice {
        attribute :>> operatingPressure = 50.0;
        attribute :>> maxTractionForce = 120.0;
        attribute :>> procedureDuration = 150.0;
        attribute :>> deviceState = DeviceState::idle;
    }
    
    satisfy primaryFunction by odonDeviceSystem;
    satisfy pressureControl by odonDeviceSystem;
    satisfy tractionLimit by odonDeviceSystem;
    satisfy cupDimension by odonDeviceSystem.rigidCup;
    satisfy procedureTime by odonDeviceSystem;
    satisfy safetyMonitoring by odonDeviceSystem;
}
