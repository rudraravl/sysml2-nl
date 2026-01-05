package MichaabWaterManagementSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WaterQuality {
        attribute turbidity : Real;
        attribute dissolvedOxygen : Real;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    attribute def WaterFlowRate :> ISQ::PowerValue;
    attribute def WaterPressure :> ISQ::PressureValue;
    attribute def WaterDepth :> ISQ::LengthValue;
    attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
    attribute def GatePosition :> Real;
    
    enum def OperationalMode {
        IDLE;
        FILLING;
        MILLING;
        IRRIGATION;
        MAINTENANCE;
    }
    
    item def WaterFlow {
        attribute flowRate : WaterFlowRate;
        attribute pressure : WaterPressure;
        attribute quality : WaterQuality;
    }
    
    port def WaterInletPort {
        in item waterIn : WaterFlow;
    }
    
    port def WaterOutletPort {
        out item waterOut : WaterFlow;
    }
    
    port def MechanicalPowerPort {
        out attribute torque : ISQ::TorqueValue;
        out attribute rotationalSpeed : RotationalSpeed;
    }
    
    attribute def OpenGateCommand;
    attribute def IncreaseFlowCommand;
    attribute def DecreaseFlowCommand;
    attribute def CloseGateCommand;
    
    part def UpperReservoir {
        attribute capacity : ISQ::VolumeValue;
        attribute currentVolume : ISQ::VolumeValue;
        attribute waterDepth : WaterDepth;
        attribute surfaceArea : ISQ::AreaValue;
        
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
        
        perform action storeWater {
            in inflowWater : WaterFlow;
            out storedWater : WaterFlow;
            
            attribute volumeChange : ISQ::VolumeValue;
        }
    }
    
    part def DistributionChannel {
        attribute length : ISQ::LengthValue;
        attribute width : ISQ::LengthValue;
        attribute slope : Real;
        attribute roughness : Real;
        
        port channelInlet : WaterInletPort;
        port channelOutlet : WaterOutletPort;
        
        perform action conveyWater {
            in upstreamFlow : WaterFlow;
            out downstreamFlow : WaterFlow;
            
            attribute flowVelocity : ISQ::SpeedValue;
        }
    }
    
    part def ControlGate {
        attribute maxOpening : ISQ::LengthValue;
        attribute currentOpening : GatePosition;
        attribute gateWidth : ISQ::LengthValue;
        
        port gateInlet : WaterInletPort;
        port gateOutlet : WaterOutletPort;
        
        state gateControl {
            entry; then fullyClosed;
            
            state fullyClosed {
                entry assign currentOpening := 0.0;
            }
            
            state quarterOpen {
                entry assign currentOpening := 0.25;
            }
            
            state halfOpen {
                entry assign currentOpening := 0.5;
            }
            
            state threeQuarterOpen {
                entry assign currentOpening := 0.75;
            }
            
            state fullyOpen {
                entry assign currentOpening := 1.0;
            }
            
            transition openToQuarter
                first fullyClosed
                accept at openGateCmd : OpenGateCommand
                then quarterOpen;
            
            transition quarterToHalf
                first quarterOpen
                accept at increaseFlowCmd1 : IncreaseFlowCommand
                then halfOpen;
            
            transition halfToThreeQuarter
                first halfOpen
                accept at increaseFlowCmd2 : IncreaseFlowCommand
                then threeQuarterOpen;
            
            transition threeQuarterToFull
                first threeQuarterOpen
                accept at increaseFlowCmd3 : IncreaseFlowCommand
                then fullyOpen;
            
            transition fullToThreeQuarter
                first fullyOpen
                accept at decreaseFlowCmd1 : DecreaseFlowCommand
                then threeQuarterOpen;
            
            transition threeQuarterToHalf
                first threeQuarterOpen
                accept at decreaseFlowCmd2 : DecreaseFlowCommand
                then halfOpen;
            
            transition halfToQuarter
                first halfOpen
                accept at decreaseFlowCmd3 : DecreaseFlowCommand
                then quarterOpen;
            
            transition quarterToClosed
                first quarterOpen
                accept at closeGateCmd : CloseGateCommand
                then fullyClosed;
        }
        
        perform action regulateFlow {
            in upstreamWater : WaterFlow;
            in gateOpening : GatePosition;
            out regulatedWater : WaterFlow;
        }
    }
    
    part def WaterWheel {
        attribute diameter : ISQ::LengthValue;
        attribute numberOfBuckets : Integer;
        attribute bucketCapacity : ISQ::VolumeValue;
        attribute wheelSpeed : RotationalSpeed;
        attribute efficiency : Real;
        
        port waterInput : WaterInletPort;
        port waterOutput : WaterOutletPort;
        port powerOutput : MechanicalPowerPort;
        
        perform action generatePower {
            in drivingWater : WaterFlow;
            out mechanicalTorque : ISQ::TorqueValue;
            out rotationSpeed : RotationalSpeed;
            out dischargedWater : WaterFlow;
        }
    }
    
    part def MillingMechanism {
        attribute upperStoneWeight : ISQ::MassValue;
        attribute lowerStoneWeight : ISQ::MassValue;
        attribute gapWidth : ISQ::LengthValue;
        attribute grindingSpeed : RotationalSpeed;
        
        port mechanicalInput : MechanicalPowerPort;
        
        perform action grindGrain {
            in driveTorque : ISQ::TorqueValue;
            in driveSpeed : RotationalSpeed;
            out grindingForce : ISQ::ForceValue;
            out outputRate : ISQ::MassFlowValue;
        }
    }
    
    part def IrrigationOutlet {
        attribute outletDiameter : ISQ::LengthValue;
        attribute numberOfOutlets : Integer;
        attribute servicedArea : ISQ::AreaValue;
        
        port waterInlet : WaterInletPort;
        
        perform action distributeWater {
            in sourceWater : WaterFlow;
            out irrigationFlow : WaterFlow;
        }
    }
    
    part def LowerReservoir {
        attribute capacity : ISQ::VolumeValue;
        attribute currentVolume : ISQ::VolumeValue;
        attribute waterDepth : WaterDepth;
        
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
        
        perform action collectWater {
            in returnFlow : WaterFlow;
            out storedWater : WaterFlow;
        }
    }
    
    action def MonitorReservoirLevel {
        in currentDepth : WaterDepth;
        in targetDepth : WaterDepth;
        out depthError : ISQ::LengthValue;
    }
    
    action def CalculateGateAdjustment {
        in depthError : ISQ::LengthValue;
        in currentGatePosition : GatePosition;
        out newGatePosition : GatePosition;
    }
    
    action def TransferMechanicalPower {
        in wheelTorque : ISQ::TorqueValue;
        in wheelSpeed : RotationalSpeed;
        out millTorque : ISQ::TorqueValue;
        out millSpeed : RotationalSpeed;
    }
    
    action def AssessWaterQuality {
        in waterSample : WaterFlow;
        out qualityStatus : Boolean;
    }
    
    part def Michaab {
        doc /* A Michaab is a traditional integrated water management and milling system
               that harnesses gravity-fed water flow through channels and reservoirs to drive
               water wheels for grain milling while simultaneously managing irrigation water
               distribution to agricultural lands. */
        
        attribute systemEfficiency : Real;
        attribute operationalMode : OperationalMode;
        attribute dailyWaterThroughput : ISQ::VolumeValue;
        attribute millingCapacity : ISQ::MassFlowValue;
        
        part upperBasin : UpperReservoir {
            attribute :>> capacity = 8000.0;
            attribute :>> surfaceArea = 2000.0;
        }
        
        part primaryChannel : DistributionChannel {
            attribute :>> length = 150.0;
            attribute :>> width = 2.5;
            attribute :>> slope = 0.02;
        }
        
        part mainGate : ControlGate {
            attribute :>> maxOpening = 1.2;
            attribute :>> gateWidth = 2.5;
        }
        
        part secondaryChannel : DistributionChannel {
            attribute :>> length = 50.0;
            attribute :>> width = 2.0;
            attribute :>> slope = 0.03;
        }
        
        part primaryWheel : WaterWheel {
            attribute :>> diameter = 5.0;
            attribute :>> numberOfBuckets = 32;
            attribute :>> bucketCapacity = 50.0;
            attribute :>> efficiency = 0.7;
        }
        
        part millstone : MillingMechanism {
            attribute :>> upperStoneWeight = 600.0;
            attribute :>> lowerStoneWeight = 800.0;
            attribute :>> gapWidth = 2.0;
        }
        
        part irrigationGate : ControlGate {
            attribute :>> maxOpening = 0.8;
            attribute :>> gateWidth = 1.5;
        }
        
        part irrigationOutlet : IrrigationOutlet {
            attribute :>> outletDiameter = 0.3;
            attribute :>> numberOfOutlets = 12;
            attribute :>> servicedArea = 50000.0;
        }
        
        part returnBasin : LowerReservoir {
            attribute :>> capacity = 5000.0;
        }
        
        connection upperToMain connect 
            upperBasin.outlet to primaryChannel.channelInlet;
        
        connection mainToGate connect 
            primaryChannel.channelOutlet to mainGate.gateInlet;
        
        connection gateToSecondary connect 
            mainGate.gateOutlet to secondaryChannel.channelInlet;
        
        connection secondaryToWheel connect 
            secondaryChannel.channelOutlet to primaryWheel.waterInput;
        
        connection wheelToReturn connect 
            primaryWheel.waterOutput to returnBasin.inlet;
        
        connection wheelToMill connect 
            primaryWheel.powerOutput to millstone.mechanicalInput;
        
        connection gateToIrrigation connect 
            mainGate.gateOutlet to irrigationGate.gateInlet;
        
        connection irrigationToOutlet connect 
            irrigationGate.gateOutlet to irrigationOutlet.waterInlet;
        
        perform action operateMichaab {
            first start;
            then merge operationLoop;
            
            action monitorUpper : MonitorReservoirLevel {
                in currentDepth = upperBasin.waterDepth;
                in targetDepth = 3.5;
                out depthError;
            }
            
            then action calculateAdjustment : CalculateGateAdjustment {
                in depthError = monitorUpper.depthError;
                in currentGatePosition = mainGate.currentOpening;
                out newGatePosition;
            }
            
            then decide;
                if calculateAdjustment.newGatePosition >= 0.75 then openMainGateFull;
                if calculateAdjustment.newGatePosition >= 0.5 and calculateAdjustment.newGatePosition < 0.75 then openMainGateThreeQuarter;
                if calculateAdjustment.newGatePosition >= 0.25 and calculateAdjustment.newGatePosition < 0.5 then openMainGateHalf;
                if calculateAdjustment.newGatePosition < 0.25 then openMainGateQuarter;
            
            action openMainGateFull {
                then send IncreaseFlowCommand to mainGate;
            }
            
            action openMainGateThreeQuarter {
                then send IncreaseFlowCommand to mainGate;
            }
            
            action openMainGateHalf {
                then send IncreaseFlowCommand to mainGate;
            }
            
            action openMainGateQuarter {
                then send OpenGateCommand to mainGate;
            }
            
            then action transferPower : TransferMechanicalPower {
                in wheelTorque;
                in wheelSpeed;
                out millTorque;
                out millSpeed;
            }
            
            then action checkQuality : AssessWaterQuality {
                in waterSample;
                out qualityStatus;
            }
            
            then decide;
                if checkQuality.qualityStatus == true then continueOperation;
                if checkQuality.qualityStatus == false then adjustIrrigation;
            
            action continueOperation;
            
            action adjustIrrigation {
                then send DecreaseFlowCommand to irrigationGate;
            }
            
            then operationLoop;
        }
    }
    
    requirement def WaterDistributionRequirement {
        doc /* The system shall maintain continuous water distribution to irrigation outlets
               while preserving minimum reservoir levels. */
        
        subject michaabSys : Michaab;
        
        require constraint maintainMinimumLevel {
            michaabSys.upperBasin.currentVolume >= 0.25 * michaabSys.upperBasin.capacity
        }
        
        require constraint ensureIrrigationFlow {
            michaabSys.irrigationOutlet.waterInlet.waterIn.flowRate >= 0.5
        }
    }
    
    requirement def MillingProductivityRequirement {
        doc /* The system shall convert hydraulic energy to mechanical power with
               minimum efficiency of 65% to support continuous grain milling operations. */
        
        subject michaabSys : Michaab;
        
        require constraint minimumHydraulicEfficiency {
            michaabSys.systemEfficiency >= 0.65
        }
        
        require constraint sustainedMillingSpeed {
            michaabSys.millstone.grindingSpeed >= 30.0
        }
    }
    
    requirement def SystemSafetyRequirement {
        doc /* The system shall prevent overflow conditions and maintain structural
               integrity under all operational scenarios. */
        
        subject michaabSys : Michaab;
        
        require constraint preventUpperOverflow {
            michaabSys.upperBasin.currentVolume <= michaabSys.upperBasin.capacity
        }
        
        require constraint preventLowerOverflow {
            michaabSys.returnBasin.currentVolume <= michaabSys.returnBasin.capacity
        }
        
        require constraint limitWheelSpeed {
            michaabSys.primaryWheel.wheelSpeed <= 15.0
        }
    }
    
    requirement def WaterQualityRequirement {
        doc /* The system shall maintain water quality suitable for agricultural
               irrigation throughout the distribution network. */
        
        subject michaabSys : Michaab;
        
        require constraint acceptableTurbidity {
            michaabSys.upperBasin.inlet.waterIn.quality.turbidity <= 50.0
        }
        
        require constraint minimumOxygen {
            michaabSys.upperBasin.inlet.waterIn.quality.dissolvedOxygen >= 5.0
        }
    }
    
    requirement michaabSystemRequirements {
        doc /* The Michaab system shall integrate water resource management with
               mechanical grain milling, providing sustainable agricultural support
               through gravity-powered hydraulic operations. */
        
        require waterDistribution : WaterDistributionRequirement;
        require millingProductivity : MillingProductivityRequirement;
        require systemSafety : SystemSafetyRequirement;
        require waterQuality : WaterQualityRequirement;
    }
    
    part michaabInstance : Michaab {
        :>> systemEfficiency = 0.68;
        :>> operationalMode = OperationalMode::MILLING;
        :>> dailyWaterThroughput = 15000.0;
        :>> millingCapacity = 500.0;
        
        satisfy michaabSystemRequirements;
    }
}
