package DustbotSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BatteryPercentage :> Real;
    attribute def BinPercentage :> Real;
    attribute def StartCommand;
    attribute def StopCommand;
    attribute def DockCommand;
    attribute def ObstacleAlert;
    attribute def DirtDetected;
    attribute def BinFull;
    attribute def CleaningComplete;
    attribute def BatteryLow;
    
    attribute def CleaningIntensity :> Real {
        doc /* Cleaning intensity level from 0.0 (off) to 1.0 (maximum) */
    }
    
    item def DustParticles {
        attribute mass : MassValue;
    }
    
    item def FloorSurface {
        attribute area : AreaValue;
        attribute dirtLevel : Real;
    }
    
    port def SensorDataPort {
        out obstacleDistance : LengthValue;
        out floorDirtLevel : Real;
        out batteryLevel : BatteryPercentage;
    }
    
    port def MotionControlPort {
        in velocity : SpeedValue;
        in heading : ISQ::AngleValue;
    }
    
    port def CleaningControlPort {
        in suctionPower : PowerValue;
        in brushSpeed : ISQ::AngularVelocityValue;
    }
    
    port def PowerSupplyPort {
        in chargingPower : PowerValue;
        out batteryVoltage : ISQ::ElectricPotentialValue;
        out batteryCurrent : ISQ::ElectricCurrentValue;
    }
    
    part def ProximitySensor {
        port dataOut : SensorDataPort;
        attribute detectionRange : LengthValue = 0.8[SI::m];
    }
    
    part def FloorSensor {
        port dataOut : SensorDataPort;
        attribute sensitivity : Real = 0.95;
    }
    
    part def NavigationModule {
        in port sensorData : SensorDataPort;
        out port motionCmd : MotionControlPort;
        attribute currentPosition : LengthValue[2];
        attribute targetPosition : LengthValue[2];
    }
    
    part def VacuumUnit {
        in port controlInput : CleaningControlPort;
        out collectedDust : DustParticles[*];
        attribute maxSuctionPower : PowerValue = 180[SI::W];
        attribute currentPower : PowerValue;
    }
    
    part def BrushAssembly {
        in port controlInput : CleaningControlPort;
        attribute maxRotationSpeed : ISQ::AngularVelocityValue = 300[SI::'rad/s'];
        attribute currentSpeed : ISQ::AngularVelocityValue;
    }
    
    part def DustBin {
        in wasteInput : DustParticles[*];
        attribute maxCapacity : MassValue = 0.6[SI::kg];
        attribute currentFill : BinPercentage = 0.0;
    }
    
    part def MotorController {
        in port motionCmd : MotionControlPort;
        attribute leftWheelSpeed : SpeedValue;
        attribute rightWheelSpeed : SpeedValue;
    }
    
    part def BatterySystem {
        port powerInterface : PowerSupplyPort;
        attribute capacity : ISQ::EnergyValue = 3600[SI::'W*h'];
        attribute chargeLevel : BatteryPercentage = 100.0;
        attribute voltage : ISQ::ElectricPotentialValue = 14.4[SI::V];
    }
    
    part def DockingStation {
        port chargingInterface : PowerSupplyPort;
        attribute outputPower : PowerValue = 50[SI::W];
    }
    
    action def ScanEnvironment {
        in sensorInput : LengthValue;
        out obstacleDetected : Boolean;
        out safeDistance : LengthValue;
    }
    
    action def EvaluateDirtLevel {
        in floorData : Real;
        out requiresCleaning : Boolean;
        out intensityLevel : CleaningIntensity;
    }
    
    action def PlanPath {
        in currentPos : LengthValue[2];
        in targetPos : LengthValue[2];
        in obstacles : Boolean;
        out pathCommands : MotionControlPort;
    }
    
    action def ActivateCleaning {
        in intensity : CleaningIntensity;
        out vacuumPower : PowerValue;
        out brushSpeed : ISQ::AngularVelocityValue;
    }
    
    action def CollectDebris {
        in suctionPower : PowerValue;
        in brushSpeed : ISQ::AngularVelocityValue;
        out debris : DustParticles[*];
    }
    
    action def NavigateToDock {
        in currentPos : LengthValue[2];
        out dockingPath : MotionControlPort;
    }
    
    action def ChargeBattery {
        in chargePower : PowerValue;
        in currentCharge : BatteryPercentage;
        out updatedCharge : BatteryPercentage;
    }
    
    action def EmptyDustBin {
        in binContents : DustParticles[*];
        out binEmpty : Boolean;
    }
    
    action def AutonomousCleaningOperation {
        first start;
        then merge mainLoop;
        
        action monitorBattery {
            out batteryOk : Boolean;
            out chargeLevel : BatteryPercentage;
        }
        
        then decide;
            if monitorBattery.batteryOk == false then initiateRecharge;
            if monitorBattery.batteryOk == true then continueOperation;
        
        action initiateRecharge {
            action navigateToDock : NavigateToDock;
            then action charge : ChargeBattery;
        }
        then mainLoop;
        
        action continueOperation {
            action scanArea {
                action scanEnv : ScanEnvironment;
                action evalDirt : EvaluateDirtLevel;
            }
            
            then decide;
                if scanArea.scanEnv.obstacleDetected == true then avoidObstacle;
                if scanArea.evalDirt.requiresCleaning == true then executeClean;
                else mainLoop;
            
            action avoidObstacle : PlanPath;
            then mainLoop;
            
            action executeClean {
                action activateClean : ActivateCleaning;
                then action collectDebris : CollectDebris;
                then action checkBin {
                    out binFull : Boolean;
                }
                then decide;
                    if checkBin.binFull == true then emptyBin;
                    else mainLoop;
                
                action emptyBin {
                    action returnToDock : NavigateToDock;
                    then action empty : EmptyDustBin;
                }
                then mainLoop;
            }
        }
        
        then mainLoop;
    }
    
    state def DustbotOperatingStates {
        entry; then standby;
        
        state standby {
            doc /* Robot is idle and awaiting commands */
        }
        accept StartCommand then active;
        
        state active {
            entry; then cleaning;
            
            state cleaning {
                entry; then navigating;
                
                state navigating {
                    do action pathPlanning : PlanPath;
                }
                accept DirtDetected then vacuuming;
                accept ObstacleAlert then avoiding;
                
                state avoiding {
                    do action obstacleAvoidance : PlanPath;
                }
                then navigating;
                
                state vacuuming {
                    do action vacuum : ActivateCleaning;
                    do action collect : CollectDebris;
                }
                accept BinFull then returning;
                accept CleaningComplete then navigating;
            }
            
            accept BatteryLow then charging;
            accept StopCommand then standby;
            
            state returning {
                do action returnNav : NavigateToDock;
            }
            accept DockCommand then docked;
            
            state docked {
                do action emptyBin : EmptyDustBin;
            }
            then cleaning;
        }
        
        state charging {
            entry action startCharge : ChargeBattery;
            do action monitorChargeAction : ChargeBattery {
                out updatedCharge;
            }
        }
        accept StartCommand then standby;
        
        accept StopCommand then standby;
    }
    
    part def Dustbot {
        doc /* 
            Autonomous robotic cleaning system that navigates indoor environments,
            detects dirt and obstacles, vacuums debris, manages battery charge,
            and empties collected waste at a docking station.
        */
        
        perform action operation : AutonomousCleaningOperation;
        exhibit state behavior : DustbotOperatingStates;
        
        part proximitySensors : ProximitySensor[6] {
            port :>> dataOut;
        }
        
        part floorSensors : FloorSensor[3] {
            port :>> dataOut;
        }
        
        part navigator : NavigationModule {
            perform operation.continueOperation.scanArea.scanEnv;
            perform operation.continueOperation.avoidObstacle;
            port :>> sensorData;
            port :>> motionCmd;
        }
        
        part vacuum : VacuumUnit {
            perform operation.continueOperation.executeClean.activateClean;
            perform operation.continueOperation.executeClean.collectDebris;
            port :>> controlInput;
            attribute :>> currentPower = 150[SI::W];
        }
        
        part brushes : BrushAssembly {
            perform operation.continueOperation.executeClean.activateClean;
            port :>> controlInput;
            attribute :>> currentSpeed = 250[SI::'rad/s'];
        }
        
        part bin : DustBin {
            attribute :>> currentFill = 0.0;
        }
        
        part motors : MotorController {
            perform operation.continueOperation.avoidObstacle;
            perform operation.initiateRecharge.navigateToDock;
            port :>> motionCmd;
        }
        
        part battery : BatterySystem {
            port :>> powerInterface;
            attribute :>> chargeLevel = 100.0;
        }
        
        connect proximitySensors.dataOut to navigator.sensorData;
        connect floorSensors.dataOut to navigator.sensorData;
        connect navigator.motionCmd to motors.motionCmd;
        connect vacuum.collectedDust to bin.wasteInput;
    }
    
    part dockingStation : DockingStation {
        port :>> chargingInterface;
        attribute :>> outputPower = 50[SI::W];
    }
    
    requirement def NavigationRequirement {
        doc /* 
            The Dustbot shall navigate autonomously while detecting and avoiding
            obstacles within 0.8 meters to prevent collisions.
        */
        
        subject robot : Dustbot;
        
        require constraint obstacleDetection {
            robot.proximitySensors.detectionRange >= 0.8[SI::m]
        }
    }
    
    requirement def CleaningRequirement {
        doc /* 
            The Dustbot shall provide effective cleaning with vacuum suction
            power of at least 150W and adjustable brush speed up to 300 rad/s.
        */
        
        subject robot : Dustbot;
        
        require constraint vacuumPower {
            robot.vacuum.currentPower >= 150[SI::W]
        }
        
        require constraint brushPerformance {
            robot.brushes.maxRotationSpeed >= 300[SI::'rad/s']
        }
    }
    
    requirement def PowerManagementRequirement {
        doc /* 
            The Dustbot shall monitor battery level and autonomously return
            to charging station when charge falls below 15%.
        */
        
        subject robot : Dustbot;
        
        assume constraint lowBatteryThreshold {
            robot.battery.chargeLevel < 15.0
        }
        
        require constraint autoRecharge {
            lowBatteryThreshold implies 
            robot.behavior == DustbotOperatingStates::charging
        }
    }
    
    requirement def WasteManagementRequirement {
        doc /* 
            The Dustbot shall collect debris until bin reaches 85% capacity,
            then autonomously return to docking station to empty.
        */
        
        subject robot : Dustbot;
        
        require constraint binCapacity {
            robot.bin.maxCapacity >= 0.6[SI::kg]
        }
        
        require constraint autoEmpty {
            robot.bin.currentFill >= 85.0 implies
            robot.behavior == DustbotOperatingStates::active::returning
        }
    }
    
    requirement def PrimaryMissionRequirement {
        doc /* 
            The Dustbot shall autonomously clean floor surfaces by navigating
            designated areas, detecting and collecting dust and debris, avoiding
            obstacles, and managing its own power and waste disposal needs.
        */
        
        require navigationReq : NavigationRequirement;
        require cleaningReq : CleaningRequirement;
        require powerReq : PowerManagementRequirement;
        require wasteReq : WasteManagementRequirement;
    }
    
    part cleaningSystem {
        part dustbot : Dustbot;
        part dock : DockingStation;
        
        connect dustbot.battery.powerInterface to dock.chargingInterface;
    }
    
    requirement primaryMission : PrimaryMissionRequirement {
        doc /* 
            System-level requirement defining the Dustbot's autonomous cleaning
            mission including navigation, debris collection, obstacle avoidance,
            battery management, and waste disposal capabilities.
        */
    }
    
    satisfy primaryMission by cleaningSystem.dustbot.operation;
}
