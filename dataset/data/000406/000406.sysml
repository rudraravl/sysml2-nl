package ElmerAndElsieSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BatteryPercentage :> Real;
    attribute def LightIntensity :> Real;
    
    item def LightSignal {
        attribute intensity : LightIntensity;
        attribute wavelength : LengthValue;
    }
    
    item def ControlSignal {
        attribute command : String;
        attribute timestamp : Real;
    }
    
    port def LightSensorPort {
        in ambientLight : LightIntensity;
        out detectedIntensity : LightIntensity;
    }
    
    port def MotorControlPort {
        in speedCommand : Real;
        out actualSpeed : Real;
    }
    
    port def HeadlampPort {
        out emittedLight : LightIntensity;
        in powerLevel : Real;
    }
    
    port def ChargingPort {
        in chargingPower : PowerValue;
        out batteryStatus : BatteryPercentage;
    }
    
    part def PhotocellSensor {
        attribute sensitivity : Real;
        attribute currentReading : LightIntensity;
        port sensorPort : LightSensorPort;
    }
    
    part def DriveMotor {
        attribute maxSpeed : Real;
        attribute currentSpeed : Real;
        port motorPort : MotorControlPort;
    }
    
    part def Headlamp {
        attribute brightness : LightIntensity;
        attribute isActive : Boolean;
        port lampPort : HeadlampPort;
    }
    
    part def Battery {
        attribute capacity : EnergyValue;
        attribute chargeLevel : BatteryPercentage;
        attribute voltage : Real;
    }
    
    part def SteeringMechanism {
        attribute turnAngle : Real;
        attribute direction : String;
    }
    
    action def SenseLightEnvironment {
        in ambientIntensity : LightIntensity;
        out detectedLight : LightIntensity;
        out lightDirection : Real;
    }
    
    action def CalculateMotorResponse {
        in lightIntensity : LightIntensity;
        in batteryLevel : BatteryPercentage;
        out motorSpeed : Real;
        out steeringAngle : Real;
    }
    
    action def ControlHeadlampState {
        in surroundingLight : LightIntensity;
        in batteryLevel : BatteryPercentage;
        out lampActive : Boolean;
        out lampBrightness : LightIntensity;
    }
    
    action def NavigateTowardLight {
        in targetIntensity : LightIntensity;
        in currentPosition : Real;
        out movementSpeed : Real;
        out turnDirection : String;
    }
    
    action def ReturnToChargingStation {
        in batteryLevel : BatteryPercentage;
        in stationBeacon : LightIntensity;
        out navigationPath : String;
    }
    
    action def PerformCharging {
        in currentCharge : BatteryPercentage;
        in chargingRate : PowerValue;
        out updatedCharge : BatteryPercentage;
    }
    
    part def TortoiseRobot {
        attribute robotMass : MassValue;
        attribute batteryCharge : BatteryPercentage;
        attribute operationalRadius : LengthValue;
        
        part photocell : PhotocellSensor {
            attribute sensitivity = 0.85;
            attribute currentReading = 50.0;
        }
        
        part motor : DriveMotor {
            attribute maxSpeed = 0.15;
            attribute currentSpeed = 0.0;
        }
        
        part headlamp : Headlamp {
            attribute brightness = 100.0;
            attribute isActive = false;
        }
        
        part battery : Battery {
            attribute capacity = 200000.0 [J];
            attribute chargeLevel = 100.0;
            attribute voltage = 6.0;
        }
        
        part steering : SteeringMechanism {
            attribute turnAngle = 0.0;
            attribute direction = "forward";
        }
        
        port sensorInterface : LightSensorPort;
        port motorInterface : MotorControlPort;
        port lampInterface : HeadlampPort;
        port chargingInterface : ChargingPort;
    }
    
    part def Elmer :> TortoiseRobot {
        attribute :>> robotMass = 2.8 [kg];
        attribute :>> batteryCharge = 100.0;
        attribute :>> operationalRadius = 15.0 [m];
        
        part :>> photocell {
            attribute :>> sensitivity = 0.90;
        }
        
        part :>> motor {
            attribute :>> maxSpeed = 0.18;
        }
        
        part :>> headlamp {
            attribute :>> brightness = 110.0;
        }
        
        part :>> battery {
            attribute :>> capacity = 220000.0 [J];
        }
        
        perform action elmerBehavior : TortoiseOperationalBehavior;
    }
    
    part def Elsie :> TortoiseRobot {
        attribute :>> robotMass = 2.6 [kg];
        attribute :>> batteryCharge = 100.0;
        attribute :>> operationalRadius = 15.0 [m];
        
        part :>> photocell {
            attribute :>> sensitivity = 0.88;
        }
        
        part :>> motor {
            attribute :>> maxSpeed = 0.16;
        }
        
        part :>> headlamp {
            attribute :>> brightness = 105.0;
        }
        
        part :>> battery {
            attribute :>> capacity = 210000.0 [J];
        }
        
        perform action elsieBehavior : TortoiseOperationalBehavior;
    }
    
    part def ChargingStation {
        attribute stationPower : PowerValue;
        attribute maxTortoises : Integer;
        attribute beaconIntensity : LightIntensity;
        
        port chargingDock1 : ChargingPort;
        port chargingDock2 : ChargingPort;
        port beaconEmitter {
            out beaconSignal : LightIntensity;
        }
    }
    
    part def OperatingEnvironment {
        attribute ambientLightLevel : LightIntensity;
        attribute areaSize : LengthValue;
        attribute surfaceType : String;
    }
    
    action def TortoiseOperationalBehavior {
        first start;
        then merge operationLoop;
        
        then action sense : SenseLightEnvironment {
            out detectedLight : LightIntensity;
            out lightDirection : Real;
        }
        
        then action evaluateBattery {
            in currentCharge : BatteryPercentage;
            out needsCharge : Boolean;
        }
        
        then decide;
            if evaluateBattery.needsCharge == true then returnToStation;
            if evaluateBattery.needsCharge == false then processLight;
        
        action processLight {
            in lightLevel : LightIntensity;
        }
        then decide;
            if processLight.lightLevel < 30.0 then activateLamp;
            if processLight.lightLevel >= 30.0 and processLight.lightLevel < 80.0 then explore;
            if processLight.lightLevel >= 80.0 then approachLight;
        
        action activateLamp : ControlHeadlampState {
            in surroundingLight = sense.detectedLight;
            in batteryLevel : BatteryPercentage;
            out lampActive = true;
            out lampBrightness : LightIntensity;
        }
        then explore;
        
        action explore : CalculateMotorResponse {
            in lightIntensity = sense.detectedLight;
            in batteryLevel : BatteryPercentage;
            out motorSpeed : Real;
            out steeringAngle : Real;
        }
        then operationLoop;
        
        action approachLight : NavigateTowardLight {
            in targetIntensity = sense.detectedLight;
            in currentPosition : Real;
            out movementSpeed : Real;
            out turnDirection : String;
        }
        then checkProximity;
        
        action checkProximity {
            in distance : Real;
            out atTarget : Boolean;
        }
        then decide;
            if checkProximity.atTarget == true then interact;
            if checkProximity.atTarget == false then operationLoop;
        
        action interact : ControlHeadlampState {
            in surroundingLight : LightIntensity;
            in batteryLevel : BatteryPercentage;
            out lampActive = false;
            out lampBrightness = 0.0;
        }
        then operationLoop;
        
        action returnToStation : ReturnToChargingStation {
            in batteryLevel : BatteryPercentage;
            in stationBeacon : LightIntensity;
            out navigationPath : String;
        }
        then charge;
        
        action charge : PerformCharging {
            in currentCharge : BatteryPercentage;
            in chargingRate : PowerValue;
            out updatedCharge : BatteryPercentage;
        }
        then decide;
            if charge.updatedCharge >= 95.0 then operationLoop;
            if charge.updatedCharge < 95.0 then charge;
    }
    
    part def ElmerAndElsieSystem {
        attribute systemPowerBudget : PowerValue;
        attribute operatingTime : TimeValue;
        attribute interactionCount : Integer;
        
        part elmer : Elmer {
            attribute :>> batteryCharge = 100.0;
        }
        
        part elsie : Elsie {
            attribute :>> batteryCharge = 100.0;
        }
        
        part station : ChargingStation {
            attribute stationPower = 30.0 [W];
            attribute maxTortoises = 2;
            attribute beaconIntensity = 95.0;
        }
        
        part environment : OperatingEnvironment {
            attribute ambientLightLevel = 45.0;
            attribute areaSize = 20.0 [m];
            attribute surfaceType = "smooth floor";
        }
        
        connection elmerCharging connect elmer.chargingInterface to station.chargingDock1;
        connection elsieCharging connect elsie.chargingInterface to station.chargingDock2;
    }
    
    requirement <'REQ-001'> primarySystemFunction {
        doc /* The Elmer and Elsie system shall demonstrate autonomous phototropic 
             * behavior where two robotic tortoises exhibit mutual attraction through 
             * light-seeking responses, creating emergent interactive patterns as they 
             * navigate toward each other's headlamps and environmental light sources.
             */
        subject system : ElmerAndElsieSystem;
    }
    
    requirement <'REQ-002'> phototropicResponse {
        doc /* Each tortoise shall autonomously detect light sources using photocell 
             * sensors and navigate toward higher light intensities, demonstrating 
             * positive phototaxis behavior.
             */
        subject elmer : Elmer;
        subject elsie : Elsie;
        
        assert constraint {
            elmer.photocell.currentReading >= 0.0 and
            elsie.photocell.currentReading >= 0.0
        }
    }
    
    requirement <'REQ-003'> headlampControl {
        doc /* Each tortoise shall activate its headlamp when ambient light falls 
             * below 30 units and deactivate when approaching bright light sources 
             * above 90 units to enable mutual attraction behavior.
             */
        subject elmer : Elmer;
        subject elsie : Elsie;
        
        assert constraint {
            elmer.headlamp.brightness >= 0.0 and
            elsie.headlamp.brightness >= 0.0
        }
    }
    
    requirement <'REQ-004'> mutualInteraction {
        doc /* The tortoises shall exhibit emergent mutual attraction behavior where 
             * each is drawn to the other's headlamp, creating dynamic circling and 
             * approach-avoidance patterns characteristic of the original Elmer and 
             * Elsie demonstration.
             */
        subject system : ElmerAndElsieSystem;
    }
    
    requirement <'REQ-005'> autonomousEnergyManagement {
        doc /* Each tortoise shall monitor its battery level and autonomously return 
             * to the charging station when charge drops below 25 percent, using the 
             * station's beacon for navigation.
             */
        subject elmer : Elmer;
        subject elsie : Elsie;
        
        assert constraint {
            elmer.batteryCharge >= 0.0 and elmer.batteryCharge <= 100.0 and
            elsie.batteryCharge >= 0.0 and elsie.batteryCharge <= 100.0
        }
    }
    
    requirement <'REQ-006'> massConstraint {
        doc /* Each tortoise robot shall have a total mass not exceeding 3.0 kg 
             * to ensure mobility and energy efficiency.
             */
        subject elmer : Elmer;
        subject elsie : Elsie;
        
        assert constraint {
            elmer.robotMass <= 3.0 [kg] and
            elsie.robotMass <= 3.0 [kg]
        }
    }
    
    requirement <'REQ-007'> continuousOperation {
        doc /* The system shall operate continuously with tortoises cycling through 
             * exploring, interacting, and recharging states to demonstrate sustained 
             * autonomous behavior.
             */
        subject system : ElmerAndElsieSystem;
        
        require primarySystemFunction;
        require phototropicResponse;
        require headlampControl;
        require mutualInteraction;
        require autonomousEnergyManagement;
    }
    
    part elmerAndElsieSystem : ElmerAndElsieSystem {
        attribute :>> systemPowerBudget = 35.0 [W];
        attribute :>> operatingTime = 10.0 [h];
        attribute :>> interactionCount = 0;
    }
    
    satisfy primarySystemFunction by elmerAndElsieSystem;
    satisfy phototropicResponse by elmerAndElsieSystem.elmer;
    satisfy phototropicResponse by elmerAndElsieSystem.elsie;
    satisfy headlampControl by elmerAndElsieSystem.elmer;
    satisfy headlampControl by elmerAndElsieSystem.elsie;
    satisfy mutualInteraction by elmerAndElsieSystem;
    satisfy autonomousEnergyManagement by elmerAndElsieSystem.elmer;
    satisfy autonomousEnergyManagement by elmerAndElsieSystem.elsie;
    satisfy massConstraint by elmerAndElsieSystem.elmer;
    satisfy massConstraint by elmerAndElsieSystem.elsie;
    satisfy continuousOperation by elmerAndElsieSystem;
}
