package 'LUCAS Mechanical CPR System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def CompressionDepthValue :> LengthValue {
        doc /* Depth of chest compression measured in millimeters */
    }
    
    attribute def CompressionRateValue :> FrequencyValue {
        doc /* Rate of chest compressions per minute */
    }
    
    attribute def CompressionForceValue :> ForceValue {
        doc /* Force applied during chest compression */
    }
    
    attribute def BatteryChargeValue :> Real {
        doc /* Battery state of charge as percentage 0-100 */
    }
    
    attribute def OperatingTimeValue :> TimeValue {
        doc /* Duration of continuous operation */
    }
    
    enum def DeviceCommand {
        powerOn;
        powerOff;
        startCPR;
        pauseCPR;
        resumeCPR;
        emergencyStop;
    }
    
    enum def DeviceStatus {
        off;
        standby;
        active;
        paused;
        stopped;
        lowBattery;
        fault;
    }
    
    item def Patient {
        attribute chestCircumference : LengthValue;
        attribute bodyMass : MassValue;
        attribute isPositioned : Boolean;
    }
    
    item def PowerSupply {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    port def PowerPort {
        inout item power : PowerSupply;
    }
    
    port def ControlPort {
        in command : DeviceCommand;
        out status : DeviceStatus;
    }
    
    port def MechanicalPort {
        out force : CompressionForceValue;
        out displacement : CompressionDepthValue;
    }
    
    port def SensorPort {
        in measuredDepth : CompressionDepthValue;
        in measuredForce : CompressionForceValue;
        in patientPresent : Boolean;
    }
    
    part def BatteryPack {
        attribute capacity : EnergyValue;
        attribute chargeLevel : BatteryChargeValue;
        attribute operatingTime : OperatingTimeValue;
        
        port powerOut : PowerPort;
        
        action def SupplyPower {
            in requiredPower : PowerValue;
            out availablePower : PowerValue;
            out remainingCharge : BatteryChargeValue;
        }
    }
    
    part def ElectricMotor {
        attribute motorSpeed : AngularVelocityValue;
        attribute motorTorque : TorqueValue;
        
        port powerIn : PowerPort;
        port mechanicalOut : MechanicalPort;
        
        action def GenerateTorque {
            in electricalPower : PowerValue;
            out mechanicalTorque : TorqueValue;
        }
    }
    
    part def CompressionPiston {
        attribute pistonPosition : LengthValue;
        attribute pistonVelocity : SpeedValue;
        
        port mechanicalIn : MechanicalPort;
        port compressionOut : MechanicalPort;
        
        action def ApplyCompression {
            in inputForce : ForceValue;
            in targetDepth : CompressionDepthValue;
            out outputForce : ForceValue;
            out actualDepth : CompressionDepthValue;
        }
    }
    
    part def SuctionCupAssembly {
        attribute isAttached : Boolean;
        attribute contactArea : AreaValue;
        
        port mechanicalInterface : MechanicalPort;
        
        action def SecureToPatient {
            in patient : Patient;
            out secured : Boolean;
        }
    }
    
    part def DepthSensor {
        attribute measurementAccuracy : LengthValue;
        
        port sensorOut : SensorPort;
        
        action def MeasureDepth {
            in pistonPosition : LengthValue;
            out depth : CompressionDepthValue;
        }
    }
    
    part def ForceSensor {
        attribute measurementRange : ForceValue;
        
        port sensorOut : SensorPort;
        
        action def MeasureForce {
            in appliedForce : ForceValue;
            out measuredForce : CompressionForceValue;
        }
    }
    
    part def ControlProcessor {
        attribute targetDepth : CompressionDepthValue;
        attribute targetRate : CompressionRateValue;
        attribute currentMode : DeviceStatus;
        
        port controlInterface : ControlPort;
        port sensorInput : SensorPort;
        port motorControl : ~ControlPort;
        port powerIn : PowerPort;
        
        action def ProcessFeedback {
            in sensorData : SensorPort;
            in targetParams : CompressionDepthValue;
            out motorCommand : DeviceCommand;
        }
    }
    
    part def UserInterface {
        attribute displayBrightness : Real;
        
        port userControl : ControlPort;
        
        action def AcceptUserInput {
            in buttonPress : DeviceCommand;
            out command : DeviceCommand;
        }
    }
    
    action def MonitorCompressionQuality {
        in currentDepth : CompressionDepthValue;
        in currentRate : CompressionRateValue;
        in targetDepth : CompressionDepthValue;
        in targetRate : CompressionRateValue;
        out qualityScore : Real;
        out withinTolerance : Boolean;
    }
    
    action def MonitorBattery {
        in currentCharge : BatteryChargeValue;
        out chargeLevel : Real;
        out lowBatteryWarning : Boolean;
    }
    
    action def MeasureCurrentDepth {
        out depth : CompressionDepthValue;
    }
    
    action def ApplyCompressionForce {
        in targetDepth : CompressionDepthValue;
        out outputForce : ForceValue;
        out actualDepth : CompressionDepthValue;
    }
    
    action def PerformCompressionCycle {
        in targetDepth : CompressionDepthValue;
        in targetRate : CompressionRateValue;
        in sensorFeedback : SensorPort;
        out actualDepth : CompressionDepthValue;
        out actualForce : ForceValue;
        
        first start;
        then merge compressionLoop;
        
        then action measureCurrent : MeasureCurrentDepth {
            out depth;
        }
        
        then decide;
            if measureCurrent.depth < targetDepth then applyForce;
            if measureCurrent.depth >= targetDepth then releaseForce;
        
        action applyForce : ApplyCompressionForce {
            in targetDepth = PerformCompressionCycle::targetDepth;
            out outputForce;
            out actualDepth;
        }
        then assign PerformCompressionCycle::actualDepth := applyForce.actualDepth;
        then compressionLoop;
        
        action releaseForce {
            then assign PerformCompressionCycle::actualForce := 0.0 [N];
        }
        then done;
    }
    
    action def ExecuteCPRProtocol {
        in targetDepth : CompressionDepthValue;
        in targetRate : CompressionRateValue;
        in sessionDuration : OperatingTimeValue;
        in controlCmd : DeviceCommand;
        in batteryLevel : BatteryChargeValue;
        out compressionCount : Integer;
        
        private attribute cycleCounter : Integer := 0;
        private attribute elapsedTimer : TimeValue := 0.0 [s];
        
        first start;
        then merge awaitStart;
        
        accept startSignal : DeviceCommand;
        
        then decide;
            if startSignal == DeviceCommand::startCPR then beginCPR;
            if startSignal == DeviceCommand::emergencyStop then terminateProtocol;
        
        action beginCPR {
            loop {
                perform action compressionCycle : PerformCompressionCycle {
                    in targetDepth = ExecuteCPRProtocol::targetDepth;
                    in targetRate = ExecuteCPRProtocol::targetRate;
                    out actualDepth;
                    out actualForce;
                }
                then assign cycleCounter := cycleCounter + 1;
                then assign elapsedTimer := elapsedTimer + (60.0 [s] / targetRate);
                
                then action checkBattery : MonitorBattery {
                    in currentCharge = batteryLevel;
                    out chargeLevel;
                }
                
                then decide;
                    if checkBattery.chargeLevel > 10.0 and elapsedTimer < sessionDuration then continueLoop;
                    if checkBattery.chargeLevel <= 10.0 or elapsedTimer >= sessionDuration then stopCPR;
                
                action continueLoop;
                action stopCPR;
            }
        }
        
        action terminateProtocol;
        then assign compressionCount := cycleCounter;
        then done;
    }
    
    state def LUCASOperatingStates {
        entry; then powerOff;
        
        state powerOff {
            entry assign systemStatus = DeviceStatus::off;
        }
        
        transition powerOff_to_standby
            first powerOff
            accept DeviceCommand::powerOn
            then standby;
        
        state standby {
            entry assign systemStatus = DeviceStatus::standby;
        }
        
        transition standby_to_active
            first standby
            accept DeviceCommand::startCPR
            if patientPositioned
            then active;
        
        state active {
            entry assign systemStatus = DeviceStatus::active;
            
            state compressionActive {
                entry; then compressing;
                
                state compressing {
                    entry assign compressionPhase = "Downstroke";
                }
                
                transition compress_to_release
                    first compressing
                    if targetDepthReached
                    then releasing;
                
                state releasing {
                    entry assign compressionPhase = "Upstroke";
                }
                
                transition release_to_compress
                    first releasing
                    if releaseComplete
                    then compressing;
            }
        }
        
        transition active_to_paused
            first active
            accept DeviceCommand::pauseCPR
            then paused;
        
        state paused {
            entry assign systemStatus = DeviceStatus::paused;
        }
        
        transition paused_to_active
            first paused
            accept DeviceCommand::resumeCPR
            then active;
        
        transition to_stopped
            first active
            accept DeviceCommand::emergencyStop
            then stopped;
        
        transition to_lowBattery
            first active
            if batteryCharge < 10.0
            then lowBattery;
        
        state stopped {
            entry assign systemStatus = DeviceStatus::stopped;
        }
        
        state lowBattery {
            entry assign systemStatus = DeviceStatus::lowBattery;
        }
        
        transition stopped_to_standby
            first stopped
            accept DeviceCommand::powerOn
            then standby;
        
        attribute systemStatus : DeviceStatus;
        attribute compressionPhase : String;
        attribute batteryCharge : Real;
        attribute patientPositioned : Boolean;
        attribute targetDepthReached : Boolean;
        attribute releaseComplete : Boolean;
    }
    
    part def LUCASDevice {
        doc /*
            LUCAS (Lund University Cardiopulmonary Assist System) is a mechanical
            chest compression device that delivers automated, consistent, and
            high-quality cardiopulmonary resuscitation (CPR) to cardiac arrest patients.
            
            Primary Function: Provide continuous, guideline-compliant chest compressions
            to maintain blood circulation during cardiac arrest, freeing medical personnel
            to perform other critical interventions.
        */
        
        attribute deviceSerialNumber : String;
        attribute targetCompressionDepth : CompressionDepthValue = 52.0 [mm];
        attribute targetCompressionRate : CompressionRateValue = 102.0 [1/min];
        attribute maxOperatingTime : OperatingTimeValue = 2700.0 [s];
        attribute deviceMass : MassValue = 7.8 [kg];
        
        part battery : BatteryPack {
            attribute capacity = 180.0 [W*h];
            attribute operatingTime = 2700.0 [s];
            
            perform cprProtocol.checkBattery;
        }
        
        part motor : ElectricMotor {
            perform cprProtocol.compressionCycle.applyForce;
        }
        
        part piston : CompressionPiston {
            perform cprProtocol.compressionCycle;
        }
        
        part suctionCup : SuctionCupAssembly;
        
        part depthSensor : DepthSensor {
            perform cprProtocol.compressionCycle.measureCurrent;
        }
        
        part forceSensor : ForceSensor;
        
        part controller : ControlProcessor {
            attribute targetDepth = targetCompressionDepth;
            attribute targetRate = targetCompressionRate;
        }
        
        part userPanel : UserInterface;
        
        port operatorInterface : ControlPort;
        
        connect battery.powerOut to motor.powerIn;
        connect battery.powerOut to controller.powerIn;
        connect motor.mechanicalOut to piston.mechanicalIn;
        connect piston.compressionOut to suctionCup.mechanicalInterface;
        connect depthSensor.sensorOut to controller.sensorInput;
        connect forceSensor.sensorOut to controller.sensorInput;
        connect userPanel.userControl to operatorInterface;
        connect controller.controlInterface to operatorInterface;
        
        perform action cprProtocol : ExecuteCPRProtocol {
            in targetDepth = targetCompressionDepth;
            in targetRate = targetCompressionRate;
            in sessionDuration = maxOperatingTime;
            out compressionCount;
        }
        
        exhibit state operatingStates : LUCASOperatingStates;
    }
    
    part lucasSystem : LUCASDevice;
    
    requirement <'LUCAS-REQ-001'> deliverEffectiveCPR {
        doc /*
            The LUCAS device shall deliver effective mechanical chest compressions
            to maintain blood circulation in cardiac arrest patients according to
            international resuscitation guidelines.
        */
        
        subject device : LUCASDevice;
        
        require compressionDepthReq;
        require compressionRateReq;
        require continuousOperationReq;
        require deviceMassReq;
    }
    
    requirement <'LUCAS-REQ-002'> compressionDepthReq {
        doc /*
            The device shall deliver chest compressions at a depth of 50-55mm
            to ensure adequate cardiac output per AHA/ERC guidelines.
        */
        
        subject device : LUCASDevice;
        
        require constraint {
            device.targetCompressionDepth >= 50.0 [mm] and
            device.targetCompressionDepth <= 55.0 [mm]
        }
    }
    
    requirement <'LUCAS-REQ-003'> compressionRateReq {
        doc /*
            The device shall maintain a compression rate of 102 compressions per minute
            with tolerance of ±2 compressions per minute.
        */
        
        subject device : LUCASDevice;
        
        require constraint {
            device.targetCompressionRate >= 100.0 [1/min] and
            device.targetCompressionRate <= 104.0 [1/min]
        }
    }
    
    requirement <'LUCAS-REQ-004'> continuousOperationReq {
        doc /*
            The device shall operate continuously for at least 45 minutes on
            battery power to support extended resuscitation efforts.
        */
        
        subject device : LUCASDevice;
        
        require constraint {
            device.battery.operatingTime >= 2700.0 [s]
        }
    }
    
    requirement <'LUCAS-REQ-005'> deviceMassReq {
        doc /*
            The total mass of the device shall not exceed 8.0 kg to ensure
            portability and ease of deployment in emergency situations.
        */
        
        subject device : LUCASDevice;
        
        require constraint {
            device.deviceMass <= 8.0 [kg]
        }
    }
    
    requirement <'LUCAS-REQ-006'> safetyRequirement {
        doc /*
            The device shall include emergency stop functionality that immediately
            halts compressions within 0.5 seconds when activated.
        */
        
        subject device : LUCASDevice;
    }
}
