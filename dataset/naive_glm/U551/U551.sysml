package FluidTransferSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types with Units =====
    
    value type PressureValue > Real {
        unit 'Pa';
    }
    
    value type FlowRateValue > Real {
        unit 'm3/s';
    }
    
    value type RotationalSpeedValue > Real {
        unit 'rev/min';
    }
    
    value type ViscosityValue > Real {
        unit 'Pa*s';
    }
    
    value type TemperatureValue > Real {
        unit 'K';
    }
    
    value type VolumeValue > Real {
        unit 'm3';
    }
    
    value type EfficiencyValue > Real {
        unit '%';
    }
    
    value type LengthValue > Real {
        unit 'm';
    }
    
    value type TorqueValue > Real {
        unit 'N*m';
    }
    
    value type ForceValue > Real {
        unit 'N';
    }
    
    // ===== Item Types =====
    
    item def Liquid {
        attribute viscosity : ViscosityValue;
        attribute temperature : TemperatureValue;
        attribute density : Real;
    }
    
    item def TransferFluid :> Liquid {
        attribute viscosity : ViscosityValue = 0.001 [Pa*s];
        attribute temperature : TemperatureValue = 293.15 [K];
    }
    
    // ===== Port Definitions =====
    
    port def FluidPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        in item liquid : Liquid;
    }
    
    port def MechanicalPowerPort {
        attribute speed : RotationalSpeedValue;
        attribute torque : TorqueValue;
    }
    
    port def SignalPort {
        attribute signalValue : Real;
    }
    
    port def CommandPort {
        attribute command : String;
    }
    
    // ===== Requirements =====
    
    requirement def MinFlowRateRequirement {
        attribute minFlowRate : FlowRateValue = 0.01 [m3/s];
        subject pump : ReciprocatingPump;
        require { pump.actualFlowRate >= minFlowRate; }
    }
    
    requirement def MaxPressureRequirement {
        attribute maxPressure : PressureValue = 500000 [Pa];
        subject pump : ReciprocatingPump;
        require { pump.dischargePressure <= maxPressure; }
    }
    
    requirement def EfficiencyRequirement {
        attribute minEfficiency : EfficiencyValue = 80 [%];
        subject pump : ReciprocatingPump;
        require { pump.operationalEfficiency >= minEfficiency; }
    }
    
    requirement def FluidCompatibilityRequirement {
        attribute minViscosity : ViscosityValue = 0.0005 [Pa*s];
        attribute maxViscosity : ViscosityValue = 0.1 [Pa*s];
        attribute minTemperature : TemperatureValue = 273.15 [K];
        attribute maxTemperature : TemperatureValue = 353.15 [K];
        subject fluid : Liquid;
        require {
            fluid.viscosity >= minViscosity and fluid.viscosity <= maxViscosity and
            fluid.temperature >= minTemperature and fluid.temperature <= maxTemperature;
        }
    }
    
    // ===== Mechanical Parts =====
    
    part def Crankshaft {
        port drivePort : MechanicalPowerPort;
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute crankRadius : LengthValue = 0.05 [m];
        attribute appliedTorque : TorqueValue;
    }
    
    part def ConnectingRod {
        attribute rodLength : LengthValue = 0.2 [m];
        attribute rodForce : ForceValue;
        port crankEnd : MechanicalPowerPort;
        port pistonEnd : MechanicalPowerPort;
    }
    
    part def Piston {
        attribute pistonDiameter : LengthValue = 0.1 [m];
        attribute strokeLength : LengthValue = 0.1 [m];
        attribute position : LengthValue;
        attribute velocity : Real;
        port rodConnection : MechanicalPowerPort;
    }
    
    part def Cylinder {
        attribute boreDiameter : LengthValue = 0.1 [m];
        attribute chamberVolume : VolumeValue;
        attribute internalPressure : PressureValue;
        port inletPort : FluidPort;
        port outletPort : FluidPort;
    }
    
    part def CheckValve {
        attribute isOpen : Boolean;
        attribute crackingPressure : PressureValue = 1000 [Pa];
        attribute flowDirection : String;
        port upstreamPort : FluidPort;
        port downstreamPort : FluidPort;
        
        action def operate {
            in pressureIn : PressureValue;
            in pressureOut : PressureValue;
            out openState : Boolean;
            
            if pressureIn - pressureOut >= crackingPressure {
                openState = true;
            } else {
                openState = false;
            }
        }
    }
    
    // ===== Instrumentation =====
    
    part def PressureGauge {
        attribute measuredPressure : PressureValue;
        attribute maxRange : PressureValue = 1000000 [Pa];
        port measurementPort : FluidPort;
        port outputPort : SignalPort;
        
        action def measure {
            in fluidPressure : PressureValue;
            out reading : PressureValue;
            reading = fluidPressure;
        }
    }
    
    part def FlowMeter {
        attribute measuredFlowRate : FlowRateValue;
        attribute maxRange : FlowRateValue = 0.1 [m3/s];
        port measurementPort : FluidPort;
        port outputPort : SignalPort;
        
        action def measure {
            in fluidFlow : FlowRateValue;
            out reading : FlowRateValue;
            reading = fluidFlow;
        }
    }
    
    // ===== Tanks =====
    
    part def SupplyTank {
        attribute capacity : VolumeValue = 1.0 [m3];
        attribute currentVolume : VolumeValue;
        attribute fluidLevel : LengthValue;
        port outletPort : FluidPort;
    }
    
    part def ReceivingTank {
        attribute capacity : VolumeValue = 1.0 [m3];
        attribute currentVolume : VolumeValue;
        attribute fluidLevel : LengthValue;
        port inletPort : FluidPort;
    }
    
    // ===== Reciprocating Pump =====
    
    part def ReciprocatingPump {
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port commandPort : CommandPort;
        port drivePort : MechanicalPowerPort;
        
        attribute actualFlowRate : FlowRateValue;
        attribute dischargePressure : PressureValue;
        attribute suctionPressure : PressureValue;
        attribute operationalEfficiency : EfficiencyValue;
        attribute operatingSpeed : RotationalSpeedValue;
        
        part crankshaft : Crankshaft;
        part connectingRod : ConnectingRod;
        part piston : Piston;
        part cylinder : Cylinder;
        part inletCheckValve : CheckValve {
            attribute flowDirection = "inlet";
        }
        part outletCheckValve : CheckValve {
            attribute flowDirection = "outlet";
        }
        
        connection crankToRod connect crankshaft.drivePort to connectingRod.crankEnd;
        connection rodToPiston connect connectingRod.pistonEnd to piston.rodConnection;
        
        connection pistonToCylinder connect piston to cylinder;
        connection inletToCylinder connect inletCheckValve.downstreamPort to cylinder.inletPort;
        connection cylinderToOutlet connect cylinder.outletPort to outletCheckValve.upstreamPort;
        
        connection suctionToInletValve connect suctionPort to inletCheckValve.upstreamPort;
        connection outletValveToDischarge connect outletCheckValve.downstreamPort to dischargePort;
        
        // State Machine for Pump Operation
        state def PumpOperation {
            entry action { operatingSpeed = 0 [rev/min]; }
            
            state idle {
                entry action { operatingSpeed = 0 [rev/min]; }
            }
            
            state starting {
                entry action { operatingSpeed = 0 [rev/min]; }
                do action {
                    var rampSpeed : RotationalSpeedValue;
                    rampSpeed = 0 [rev/min];
                    while operatingSpeed < 1500 [rev/min] {
                        operatingSpeed = operatingSpeed + 50 [rev/min];
                    }
                }
            }
            
            state running {
                state suctionStroke {
                    entry action {
                        piston.position = piston.position - 0.01 [m];
                        cylinder.internalPressure = suctionPressure;
                        inletCheckValve.isOpen = true;
                        outletCheckValve.isOpen = false;
                    }
                    do action {
                        cylinder.chamberVolume = cylinder.chamberVolume + 0.0001 [m3];
                        cylinder.internalPressure = cylinder.internalPressure - 5000 [Pa];
                    }
                }
                
                state dischargeStroke {
                    entry action {
                        piston.position = piston.position + 0.01 [m];
                        cylinder.internalPressure = dischargePressure;
                        inletCheckValve.isOpen = false;
                        outletCheckValve.isOpen = true;
                    }
                    do action {
                        cylinder.chamberVolume = cylinder.chamberVolume - 0.0001 [m3];
                        cylinder.internalPressure = cylinder.internalPressure + 5000 [Pa];
                    }
                }
                
                transition suctionToDischarge
                    source suctionStroke
                    target dischargeStroke
                    when piston.position <= 0.0 [m];
                
                transition dischargeToSuction
                    source dischargeStroke
                    target suctionStroke
                    when piston.position >= 0.1 [m];
            }
            
            state stopping {
                entry action { }
                do action {
                    while operatingSpeed > 0 [rev/min] {
                        operatingSpeed = operatingSpeed - 50 [rev/min];
                    }
                }
            }
            
            transition idleToStarting
                source idle
                target starting
                when commandPort.command == "start";
            
            transition startingToRunning
                source starting
                target running
                when operatingSpeed >= 1500 [rev/min];
            
            transition runningToStopping
                source running
                target stopping
                when commandPort.command == "stop";
            
            transition stoppingToIdle
                source stopping
                target idle
                when operatingSpeed <= 0 [rev/min];
        }
        
        state operation : PumpOperation;
        
        // Pump action for one complete cycle
        action def pumpCycle {
            in suctionFluid : Liquid;
            out dischargeFluid : Liquid;
            
            var suctionVolume : VolumeValue;
            var dischargeVolume : VolumeValue;
            
            // Suction phase
            action suctionPhase {
                cylinder.internalPressure = suctionPressure;
                inletCheckValve.isOpen = true;
                outletCheckValve.isOpen = false;
                suctionVolume = piston.strokeLength * 3.14159 * (piston.pistonDiameter / 2) ^ 2;
            }
            
            // Discharge phase
            action dischargePhase {
                cylinder.internalPressure = dischargePressure;
                inletCheckValve.isOpen = false;
                outletCheckValve.isOpen = true;
                dischargeVolume = suctionVolume;
                actualFlowRate = dischargeVolume * (operatingSpeed / 60);
            }
        }
    }
    
    // ===== Fluid Transfer System =====
    
    part def FluidTransferSystem {
        part supplyTank : SupplyTank {
            attribute currentVolume : VolumeValue = 0.8 [m3];
        }
        part receivingTank : ReceivingTank {
            attribute currentVolume : VolumeValue = 0.0 [m3];
        }
        part pump : ReciprocatingPump;
        part suctionGauge : PressureGauge;
        part dischargeGauge : PressureGauge;
        part flowMeter : FlowMeter;
        
        // Connections between system components
        connection supplyToPump connect supplyTank.outletPort to pump.suctionPort;
        connection pumpToReceiving connect pump.dischargePort to receivingTank.inletPort;
        
        connection suctionGaugeConnection connect pump.suctionPort to suctionGauge.measurementPort;
        connection dischargeGaugeConnection connect pump.dischargePort to dischargeGauge.measurementPort;
        connection flowMeterConnection connect pump.dischargePort to flowMeter.measurementPort;
        
        // Requirements satisfaction
        satisfy minFlowReq : MinFlowRateRequirement by pump;
        satisfy maxPressReq : MaxPressureRequirement by pump;
        satisfy effReq : EfficiencyRequirement by pump;
        satisfy fluidCompatReq : FluidCompatibilityRequirement by supplyTank.outletPort.liquid;
        
        // System-level action
        action def transferFluid {
            in sourceFluid : Liquid;
            out transferredFluid : Liquid;
            
            var cyclesCompleted : Integer = 0;
            var totalTransferred : VolumeValue = 0 [m3];
            
            while supplyTank.currentVolume > 0 [m3] and receivingTank.currentVolume < receivingTank.capacity {
                action executeCycle : pump.pumpCycle {
                    in suctionFluid = sourceFluid;
                    out dischargeFluid = transferredFluid;
                }
                cyclesCompleted = cyclesCompleted + 1;
                totalTransferred = totalTransferred + 0.0008 [m3];
                supplyTank.currentVolume = supplyTank.currentVolume - 0.0008 [m3];
                receivingTank.currentVolume = receivingTank.currentVolume + 0.0008 [m3];
            }
        }
    }
}
