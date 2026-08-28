package HouseholdClothesDryerModel {

    // Value Types & Units
    unit def degC;
    unit def percent;
    unit def rpm;
    unit def W;
    
    value type TemperatureValue :> Real { unit degC; }
    value type MoisturePercentage :> Real { unit percent; }
    value type RotationalSpeed :> Real { unit rpm; }
    value type ElectricalPower :> Real { unit W; }
    
    // Enumerations
    enum def CycleTypeEnum { enum cotton; enum delicates; }
    enum def DoorStateEnum { enum open; enum closed; }
    
    // Item Definitions
    item def Air;
    item def Lint;
    item def WetLaundry;
    item def DryLaundry;
    
    // Port Definitions
    port def AirInPort { in item air : Air; }
    port def AirOutPort { out item air : Air; }
    port def LintOutPort { out item lint : Lint; }
    port def WetLaundryInPort { in item laundry : WetLaundry; }
    port def DryLaundryOutPort { out item laundry : DryLaundry; }
    
    port def MechDrivePort { out speed : RotationalSpeed; }
    port def MechDrivenPort { in speed : RotationalSpeed; }
    
    port def PowerInPort { in power : ElectricalPower; }
    
    port def ControlCmdPort { out cmd : CycleTypeEnum; }
    port def DoorStatusPort { out state : DoorStateEnum; }
    port def TempSensorPort { out temp : TemperatureValue; }
    port def MoistureSensorPort { out moisture : MoisturePercentage; }
    
    port def HeaterControlPort { in powerOn : Boolean; }
    port def MotorControlPort { in driveOn : Boolean; }
    port def BlowerControlPort { in blowerOn : Boolean; }
    
    // Action Definitions
    action def TumbleAction {
        in item laundry : WetLaundry;
        out item laundry : DryLaundry;
    }
    
    // Part Definitions
    part def DriveMotor {
        port powerIn : PowerInPort;
        port cmdIn : MotorControlPort;
        port driveOut : MechDrivePort;
        attribute currentSpeed : RotationalSpeed = 0 [rpm];
    }
    
    part def Blower {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port powerIn : PowerInPort;
        port cmdIn : BlowerControlPort;
    }
    
    part def HeatingElement {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port cmdIn : HeaterControlPort;
    }
    
    part def LintFilter {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port lintOut : LintOutPort;
    }
    
    part def ExhaustDuct {
        port airIn : AirInPort;
        port airOut : AirOutPort;
    }
    
    part def Drum {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port driveIn : MechDrivenPort;
        port laundryIn : WetLaundryInPort;
        port laundryOut : DryLaundryOutPort;
        
        action tumble : TumbleAction;
    }
    
    part def ControlPanel {
        port cmdOut : ControlCmdPort;
        attribute selectedCycle : CycleTypeEnum;
    }
    
    part def TemperatureSensor {
        port tempOut : TempSensorPort;
        attribute currentTemp : TemperatureValue;
    }
    
    part def MoistureSensor {
        port moistOut : MoistureSensorPort;
        attribute currentMoisture : MoisturePercentage;
    }
    
    part def Door {
        port doorOut : DoorStatusPort;
        attribute state : DoorStateEnum;
    }
    
    part def ControlModule {
        port cmdIn : ControlCmdPort;
        port tempIn : TempSensorPort;
        port moistIn : MoistureSensorPort;
        port doorIn : DoorStatusPort;
        
        port heaterOut : HeaterControlPort;
        port motorOut : MotorControlPort;
        port blowerOut : BlowerControlPort;
        
        attribute targetMoisture : MoisturePercentage = 10 [percent];
        attribute targetTemp : TemperatureValue = 30 [degC];
        
        state machine ControlStateMachine {
            state Idle;
            state Heating;
            state CoolDown;
            state Stopped;
            
            transition initial to Idle;
            
            transition Idle to Heating 
                accept StartCycle 
                if doorIn.state == DoorStateEnum::closed;
                
            transition Heating to CoolDown 
                when moistIn.moisture <= targetMoisture;
                
            transition Heating to Stopped 
                when doorIn.state == DoorStateEnum::open;
                
            transition CoolDown to Stopped 
                when doorIn.state == DoorStateEnum::open;
                
            transition CoolDown to Idle 
                when tempIn.temp <= targetTemp; 
                
            transition Stopped to Idle 
                accept ResetCycle;
        }
    }
    
    // System Definition
    part def HouseholdClothesDryer {
        port ambientAirIntake : AirInPort;
        port exhaustAirOut : AirOutPort;
        port laundryIn : WetLaundryInPort;
        port laundryOut : DryLaundryOutPort;
        
        part drum : Drum;
        part driveMotor : DriveMotor;
        part blower : Blower;
        part heatingElement : HeatingElement;
        part lintFilter : LintFilter;
        part exhaustDuct : ExhaustDuct;
        part controlModule : ControlModule;
        part controlPanel : ControlPanel;
        part temperatureSensor : TemperatureSensor;
        part moistureSensor : MoistureSensor;
        part door : Door;
        
        // Air flow connections
        connection ambientAir connects ambientAirIntake to blower.airIn;
        connection heatedAir connects blower.airOut to heatingElement.airIn;
        connection hotAirToDrum connects heatingElement.airOut to drum.airIn;
        connection drumToFilter connects drum.airOut to lintFilter.airIn;
        connection filterToDuct connects lintFilter.airOut to exhaustDuct.airIn;
        connection exhaustAir connects exhaustDuct.airOut to exhaustAirOut;
        
        // Mechanical connections
        connection drivePower connects driveMotor.driveOut to drum.driveIn;
        
        // Laundry connections
        connection laundryInFlow connects laundryIn to drum.laundryIn;
        connection laundryOutFlow connects drum.laundryOut to laundryOut;
        
        // Control/Sensor connections
        connection userCmd connects controlPanel.cmdOut to controlModule.cmdIn;
        connection tempFeedback connects temperatureSensor.tempOut to controlModule.tempIn;
        connection moistureFeedback connects moistureSensor.moistOut to controlModule.moistIn;
        connection doorFeedback connects door.doorOut to controlModule.doorIn;
        
        connection heaterCmd connects controlModule.heaterOut to heatingElement.cmdIn;
        connection motorCmd connects controlModule.motorOut to driveMotor.cmdIn;
        connection blowerCmd connects controlModule.blowerOut to blower.cmdIn;
    }
    
    // Requirements
    requirement def DryClothesRequirement {
        doc /* The system shall remove moisture from fabrics until they reach a specific dryness level set by the user. */
        subject dryer : HouseholdClothesDryer;
        constraint { dryer.moistureSensor.currentMoisture <= dryer.controlModule.targetMoisture }
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall not operate unless the door is securely closed and will stop immediately if opened mid-cycle. */
        subject dryer : HouseholdClothesDryer;
        constraint { dryer.door.state == DoorStateEnum::closed }
    }
    
}
