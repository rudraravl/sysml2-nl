package CytocentrifugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def RotationalSpeed :> Real {
        attribute unit : String = "rpm";
    }
    
    attribute def AccelerationValue :> Real {
        attribute unit : String = "rpm/s";
    }
    
    item def BiologicalSample {
        attribute volume : VolumeValue;
        attribute cellConcentration : Real;
        attribute sampleIdentifier : String;
    }
    
    item def PreparedSlide {
        attribute slideID : String;
        attribute monolayerQuality : Real;
        attribute cellCount : Integer;
        attribute preparationTimestamp : TimeValue;
    }
    
    enum def SpeedMode {
        enum low;
        enum medium;
        enum high;
        enum custom;
    }
    
    enum def SystemState {
        enum idle;
        enum loading;
        enum accelerating;
        enum spinning;
        enum decelerating;
        enum complete;
        enum fault;
    }
    
    part def RotorAssembly {
        attribute currentSpeed : RotationalSpeed;
        attribute maxSpeed : RotationalSpeed;
        attribute balanceStatus : Boolean;
        
        part sampleChamber[1..12] {
            attribute chamberID : Integer;
            attribute occupied : Boolean;
        }
        
        port mechanicalInterface;
    }
    
    part def FilterCardAssembly {
        attribute poreSize : LengthValue;
        attribute absorptionCapacity : VolumeValue;
        
        part filterMembrane {
            attribute material : String;
            attribute thickness : LengthValue;
        }
        
        part absorbentPad {
            attribute saturationLevel : Real;
        }
    }
    
    part def SlideCarrier {
        attribute capacity : Integer;
        attribute loadedCount : Integer;
        
        part slideClip[1..12] {
            attribute position : Integer;
            attribute slidePresent : Boolean;
        }
    }
    
    part def DriveMotor {
        attribute ratedPower : PowerValue;
        attribute targetSpeed : RotationalSpeed;
        attribute actualSpeed : RotationalSpeed;
        
        port powerInput;
        port mechanicalOutput;
        port controlInput;
        
        part speedSensor {
            attribute measuredRPM : RotationalSpeed;
        }
    }
    
    part def ControllerUnit {
        attribute operatingMode : SpeedMode;
        attribute spinDuration : TimeValue;
        attribute accelerationRate : AccelerationValue;
        
        port motorCommand;
        port safetyInput;
        port userInterface;
    }
    
    part def SafetySystem {
        attribute lidLocked : Boolean;
        attribute rotorBalanced : Boolean;
        attribute emergencyStop : Boolean;
        attribute vibrationLevel : Real;
        
        port statusOutput;
        port lidSensor;
        port balanceSensor;
    }
    
    part def UserPanel {
        attribute selectedMode : SpeedMode;
        attribute displayedState : SystemState;
        attribute timerValue : TimeValue;
        
        port userInput;
        port displayOutput;
    }
    
    part def Cytocentrifuge {
        attribute systemState : SystemState;
        attribute totalRunTime : TimeValue;
        attribute samplesProcessed : Integer;
        
        part rotor : RotorAssembly {
            attribute :>> maxSpeed = 2000.0;
            attribute :>> balanceStatus = true;
        }
        
        part filterCards : FilterCardAssembly[1..12] {
            attribute :>> poreSize = 5.0e-6 [m];
        }
        
        part slideCarrier : SlideCarrier {
            attribute :>> capacity = 12;
            attribute :>> loadedCount = 0;
        }
        
        part motor : DriveMotor {
            attribute :>> ratedPower = 250.0 [W];
            attribute :>> targetSpeed = 0.0;
        }
        
        part controller : ControllerUnit {
            attribute :>> operatingMode = SpeedMode::medium;
            attribute :>> spinDuration = 300.0 [s];
        }
        
        part safety : SafetySystem {
            attribute :>> lidLocked = false;
            attribute :>> rotorBalanced = true;
            attribute :>> emergencyStop = false;
        }
        
        part userPanel : UserPanel {
            attribute :>> selectedMode = SpeedMode::medium;
            attribute :>> displayedState = SystemState::idle;
        }
        
        connection motorDrive connect motor.mechanicalOutput to rotor.mechanicalInterface;
        connection motorControl connect controller.motorCommand to motor.controlInput;
        connection safetyMonitor connect safety.statusOutput to controller.safetyInput;
        connection userControl connect userPanel.userInput to controller.userInterface;
    }
    
    action def LoadSample {
        in sample : BiologicalSample;
        in chamberIndex : Integer;
        out loadSuccess : Boolean;
    }
    
    action def InstallSlide {
        in slidePosition : Integer;
        out slideReady : Boolean;
    }
    
    action def PerformSafetyCheck {
        in lidStatus : Boolean;
        in balanceStatus : Boolean;
        in emergencyStatus : Boolean;
        out safeToOperate : Boolean;
    }
    
    action def AccelerateRotor {
        in targetSpeed : RotationalSpeed;
        in accelerationRate : AccelerationValue;
        out speedAchieved : Boolean;
    }
    
    action def MaintainSpin {
        in speed : RotationalSpeed;
        in duration : TimeValue;
        out spinComplete : Boolean;
    }
    
    action def DecelerateRotor {
        in decelerationRate : AccelerationValue;
        out rotorStopped : Boolean;
    }
    
    action def DepositCells {
        in sample : BiologicalSample;
        out depositionComplete : Boolean;
    }
    
    action def RetrieveSlide {
        in slidePosition : Integer;
        out preparedSlide : PreparedSlide;
    }
    
    action def PrepareCytologicalSample {
        doc /* Primary function: Concentrate cells from a liquid biological sample
             * onto a microscope slide in a uniform monolayer by controlled 
             * centrifugation through a porous filter membrane.
             */
        
        in inputSample : BiologicalSample;
        out outputSlide : PreparedSlide;
        
        first start;
        
        then action loadSample : LoadSample {
            in sample = inputSample;
            in chamberIndex = 1;
        }
        
        then action installSlide : InstallSlide {
            in slidePosition = 1;
        }
        
        then action safetyCheck : PerformSafetyCheck;
        
        then action accelerate : AccelerateRotor {
            in targetSpeed = 1000.0;
            in accelerationRate = 300.0;
        }
        
        then action spin : MaintainSpin {
            in speed = 1000.0;
            in duration = 300.0 [s];
        }
        
        then action depositCells : DepositCells {
            in sample = inputSample;
        }
        
        then action decelerate : DecelerateRotor {
            in decelerationRate = 200.0;
        }
        
        then action retrieveSlide : RetrieveSlide {
            in slidePosition = 1;
            out preparedSlide = outputSlide;
        }
        
        then done;
    }
    
    state def CytocentrifugeOperation {
        entry; then idle;
        
        state idle {
            entry assign systemState = SystemState::idle;
        }
        
        transition idle_to_loading
            first idle
            then loading;
        
        state loading {
            entry assign systemState = SystemState::loading;
        }
        
        transition loading_to_accelerating
            first loading
            then accelerating;
        
        state accelerating {
            entry assign systemState = SystemState::accelerating;
        }
        
        transition accelerating_to_spinning
            first accelerating
            then spinning;
        
        state spinning {
            entry assign systemState = SystemState::spinning;
        }
        
        transition spinning_to_decelerating
            first spinning
            then decelerating;
        
        state decelerating {
            entry assign systemState = SystemState::decelerating;
        }
        
        transition decelerating_to_complete
            first decelerating
            then complete;
        
        state complete {
            entry assign systemState = SystemState::complete;
        }
        
        transition complete_to_idle
            first complete
            then idle;
    }
    
    requirement <'REQ-CYT-001'> primaryFunction {
        doc /* The cytocentrifuge shall concentrate cells from liquid biological 
             * samples onto microscope slides to create uniform monolayers suitable 
             * for cytological examination and diagnostic analysis.
             */
        
        subject cytocentrifuge : Cytocentrifuge;
        
        require speedControlRequirement;
        require cellDepositionRequirement;
        require safetyRequirement;
        require capacityRequirement;
    }
    
    requirement <'REQ-CYT-002'> speedControlRequirement {
        doc /* The system shall control rotor speed between 400 and 2000 rpm
             * with acceleration not exceeding 500 rpm/s to prevent cell damage.
             */
        
        subject motor :>> Cytocentrifuge::motor;
        
        assert constraint {
            motor.targetSpeed >= 400.0 &&
            motor.targetSpeed <= 2000.0
        }
    }
    
    requirement <'REQ-CYT-003'> cellDepositionRequirement {
        doc /* The system shall deposit cells in a monolayer with diameter
             * between 4 and 8 mm on standard microscope slides using filter
             * cards with pore size between 3 and 10 micrometers.
             */
        
        subject filterCard :>> Cytocentrifuge::filterCards;
        
        assert constraint {
            filterCard.poreSize >= 3.0e-6 [m] &&
            filterCard.poreSize <= 10.0e-6 [m]
        }
    }
    
    requirement <'REQ-CYT-004'> safetyRequirement {
        doc /* The system shall not operate unless the lid is locked, rotor
             * is balanced, and no emergency stop condition is active.
             */
        
        subject safety :>> Cytocentrifuge::safety;
        
        assert constraint {
            safety.lidLocked &&
            safety.rotorBalanced &&
            !safety.emergencyStop
        }
    }
    
    requirement <'REQ-CYT-005'> capacityRequirement {
        doc /* The system shall process up to 12 samples simultaneously
             * with independent filter cards and slide positions.
             */
        
        subject rotor :>> Cytocentrifuge::rotor;
    }
    
    part cytocentrifugeSystem : Cytocentrifuge {
        attribute :>> systemState = SystemState::idle;
        attribute :>> totalRunTime = 0.0 [s];
        attribute :>> samplesProcessed = 0;
        
        perform action prepareSample[*] ordered references PrepareCytologicalSample;
        
        exhibit state operationalBehavior : CytocentrifugeOperation;
    }
    
    satisfy primaryFunction by cytocentrifugeSystem;
}
