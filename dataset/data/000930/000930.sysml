package RotaryCompressionPumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def Pressure :> Real;
        attribute def FlowRate :> Real;
        attribute def RotationalSpeed :> Real;
        attribute def Power :> Real;
        attribute def Temperature :> Real;
        attribute def Torque :> Real;
        attribute def Efficiency :> Real;
        
        item def Fluid {
            attribute density : Real;
            attribute viscosity : Real;
            attribute temperature : Temperature;
            attribute pressure : Pressure;
        }
        
        item def MechanicalPowerItem {
            attribute power : Power;
            attribute speed : RotationalSpeed;
            attribute torque : Torque;
        }
        
        port def FluidInPort {
            attribute inletPressure : Pressure;
            attribute inletFlowRate : FlowRate;
            in item fluidIn : Fluid;
        }
        
        port def FluidOutPort {
            attribute outletPressure : Pressure;
            attribute outletFlowRate : FlowRate;
            out item fluidOut : Fluid;
        }
        
        port def PowerPort {
            attribute voltage : Real;
            attribute current : Real;
            in item electricalPower : Real;
        }
        
        port def MechanicalPort {
            attribute speed : RotationalSpeed;
            attribute torque : Torque;
            out item mechanicalPower : MechanicalPowerItem;
        }
        
        part def RotaryCompressionPump {
            attribute displacementVolume : Real;
            attribute maxPressure : Pressure;
            attribute maxSpeed : RotationalSpeed;
            attribute volumetricEfficiency : Efficiency;
            attribute mechanicalEfficiency : Efficiency;
            
            port suctionPort : FluidInPort;
            port dischargePort : FluidOutPort;
            port drivePort : ~MechanicalPort;
            
            part rotorAssembly {
                attribute rotorDiameter : Real;
                attribute eccentricity : Real;
                attribute numberOfVanes : Integer;
                
                part vanes[numberOfVanes] {
                    attribute vaneLength : Real;
                    attribute vaneThickness : Real;
                }
            }
            
            part statorHousing {
                attribute innerDiameter : Real;
                attribute wallThickness : Real;
            }
            
            part shaft {
                attribute shaftDiameter : Real;
                attribute currentSpeed : RotationalSpeed;
            }
            
            part bearings[2] {
                attribute loadRating : Real;
            }
            
            part seals[2] {
                attribute sealType : String;
                attribute leakageRate : FlowRate;
            }
            
            perform action compressFluid : CompressFluid {
                in suctionFluid = suctionPort.fluidIn;
                in driveSpeed = drivePort.speed;
                out dischargeFluid = dischargePort.fluidOut;
            }
        }
        
        part def ElectricMotor {
            attribute ratedPower : Power;
            attribute ratedSpeed : RotationalSpeed;
            attribute ratedTorque : Torque;
            attribute motorEfficiency : Efficiency;
            
            port powerInput : PowerPort;
            port mechanicalOutput : MechanicalPort;
            
            perform action convertPower {
                in electricalInput = powerInput.electricalPower;
                out mechanicalOutput = mechanicalOutput.mechanicalPower;
            }
        }
        
        part def FluidReservoir {
            attribute capacity : Real;
            attribute currentLevel : Real;
            attribute minLevel : Real;
            attribute maxLevel : Real;
            
            port outletPort : FluidOutPort;
            
            item storedFluid : Fluid {
                attribute volume : Real;
            }
            
            assert constraint levelConstraint {
                currentLevel >= minLevel and currentLevel <= maxLevel
            }
        }
        
        part def PressureVessel {
            attribute capacity : Real;
            attribute designPressure : Pressure;
            attribute currentPressure : Pressure;
            attribute safetyFactor : Real;
            
            port inletPort : FluidInPort;
            
            item containedFluid : Fluid {
                attribute volume : Real;
            }
            
            assert constraint pressureSafety {
                currentPressure <= designPressure / safetyFactor
            }
        }
        
        part def PressureSensor {
            attribute measurementRange : Pressure;
            attribute accuracy : Real;
            
            port sensingPort {
                in attribute measuredPressure : Pressure;
            }
            port outputPort {
                out attribute pressureReading : Pressure;
            }
        }
        
        part def FlowMeter {
            attribute measurementRange : FlowRate;
            attribute accuracy : Real;
            
            port sensingPort {
                in attribute measuredFlow : FlowRate;
            }
            port outputPort {
                out attribute flowReading : FlowRate;
            }
        }
        
        part def CheckValve {
            attribute crackingPressure : Pressure;
            
            port inletPort : FluidInPort;
            port outletPort : FluidOutPort;
        }
        
        part def ReliefValve {
            attribute setPressure : Pressure;
            attribute flowCapacity : FlowRate;
            
            port inletPort : FluidInPort;
            port reliefPort : FluidOutPort;
        }
        
        part def Strainer {
            attribute meshSize : Real;
            attribute pressureDrop : Pressure;
            
            port inletPort : FluidInPort;
            port outletPort : FluidOutPort;
        }
        
        action def CompressFluid {
            in suctionFluid : Fluid;
            in driveSpeed : RotationalSpeed;
            out dischargeFluid : Fluid;
            
            first start;
            then action intakeStroke {
                in fluid = suctionFluid;
                out trappedFluid : Fluid;
            }
            then action compressionStroke {
                in fluid = intakeStroke.trappedFluid;
                out compressedFluid : Fluid;
            }
            then action dischargeStroke {
                in fluid = compressionStroke.compressedFluid;
                out :>> dischargeFluid;
            }
            then done;
        }
        
        requirement def FlowRateRequirement {
            subject pump : RotaryCompressionPump;
            
            doc /* The pump shall deliver a minimum flow rate of 50 liters per minute at rated speed */
            
            require constraint {
                pump.dischargePort.outletFlowRate >= 50.0
            }
        }
        
        requirement def PressureRequirement {
            subject pump : RotaryCompressionPump;
            
            doc /* The pump shall maintain discharge pressure between 5 and 8 bar during normal operation */
            
            require constraint {
                pump.dischargePort.outletPressure >= 5.0 and
                pump.dischargePort.outletPressure <= 8.0
            }
        }
        
        requirement def EfficiencyRequirement {
            subject pump : RotaryCompressionPump;
            
            doc /* The pump shall operate with a minimum overall efficiency of 70% */
            
            require constraint {
                pump.volumetricEfficiency * pump.mechanicalEfficiency >= 0.70
            }
        }
        
        requirement def ReliabilityRequirement {
            subject subsystem : PumpingSubsystem;
            
            doc /* The subsystem shall achieve a mean time between failures of at least 8000 hours */
        }
        
        part def PumpingSubsystem {
            port systemInlet : FluidInPort;
            port systemOutlet : FluidOutPort;
            port powerSupply : PowerPort;
        }
    }
    
    package Usages {
        part pumpingSystem : Definitions::PumpingSubsystem {
            
            part sourceReservoir : Definitions::FluidReservoir {
                attribute :>> capacity = 200.0;
                attribute :>> currentLevel = 150.0;
                attribute :>> minLevel = 20.0;
                attribute :>> maxLevel = 190.0;
                
                item :>> storedFluid : Definitions::Fluid {
                    attribute :>> density = 880.0;
                    attribute :>> viscosity = 0.045;
                    attribute :>> temperature = 298.15;
                    attribute :>> pressure = 1.0;
                }
            }
            
            flow from sourceReservoir.outletPort.fluidOut to suctionStrainer.inletPort.fluidIn;
            
            part suctionStrainer : Definitions::Strainer {
                attribute :>> meshSize = 0.15;
                attribute :>> pressureDrop = 0.05;
            }
            
            flow from suctionStrainer.outletPort.fluidOut to suctionPressureSensor.sensingPort;
            
            part suctionPressureSensor : Definitions::PressureSensor {
                attribute :>> measurementRange = 2.0;
                attribute :>> accuracy = 0.01;
            }
            
            flow from suctionPressureSensor.sensingPort to rotaryPump.suctionPort.fluidIn;
            
            part rotaryPump : Definitions::RotaryCompressionPump {
                attribute :>> displacementVolume = 0.08;
                attribute :>> maxPressure = 10.0;
                attribute :>> maxSpeed = 1450.0;
                attribute :>> volumetricEfficiency = 0.92;
                attribute :>> mechanicalEfficiency = 0.85;
                
                part :>> rotorAssembly {
                    attribute :>> rotorDiameter = 65.0;
                    attribute :>> eccentricity = 6.5;
                    attribute :>> numberOfVanes = 10;
                }
                
                part :>> statorHousing {
                    attribute :>> innerDiameter = 78.0;
                    attribute :>> wallThickness = 8.0;
                }
            }
            
            part driveMotor : Definitions::ElectricMotor {
                attribute :>> ratedPower = 3000.0;
                attribute :>> ratedSpeed = 1450.0;
                attribute :>> ratedTorque = 19.8;
                attribute :>> motorEfficiency = 0.88;
            }
            
            bind driveMotor.powerInput = powerSupply;
            
            connection motorCoupling
                connect driveMotor.mechanicalOutput to rotaryPump.drivePort;
            
            flow from rotaryPump.dischargePort.fluidOut to dischargeCheckValve.inletPort.fluidIn;
            
            part dischargeCheckValve : Definitions::CheckValve {
                attribute :>> crackingPressure = 0.3;
            }
            
            flow from dischargeCheckValve.outletPort.fluidOut to dischargePressureSensor.sensingPort;
            
            part dischargePressureSensor : Definitions::PressureSensor {
                attribute :>> measurementRange = 12.0;
                attribute :>> accuracy = 0.01;
            }
            
            flow from dischargePressureSensor.sensingPort to dischargeFlowMeter.sensingPort;
            
            part dischargeFlowMeter : Definitions::FlowMeter {
                attribute :>> measurementRange = 120.0;
                attribute :>> accuracy = 0.02;
            }
            
            flow from dischargeFlowMeter.sensingPort to systemReliefValve.inletPort.fluidIn;
            
            part systemReliefValve : Definitions::ReliefValve {
                attribute :>> setPressure = 9.0;
                attribute :>> flowCapacity = 100.0;
            }
            
            flow from systemReliefValve.reliefPort.fluidOut to sourceReservoir.outletPort.fluidIn;
            
            flow from systemReliefValve.inletPort.fluidOut to destinationVessel.inletPort.fluidIn;
            
            part destinationVessel : Definitions::PressureVessel {
                attribute :>> capacity = 80.0;
                attribute :>> designPressure = 15.0;
                attribute :>> currentPressure = 6.5;
                attribute :>> safetyFactor = 1.5;
                
                item :>> containedFluid : Definitions::Fluid {
                    attribute :>> density = 880.0;
                    attribute :>> viscosity = 0.045;
                }
            }
            
            bind destinationVessel.inletPort = systemOutlet;
            
            satisfy flowReq : Definitions::FlowRateRequirement {
                subject pump = pumpingSystem.rotaryPump;
            }
            
            satisfy pressureReq : Definitions::PressureRequirement {
                subject pump = pumpingSystem.rotaryPump;
            }
            
            satisfy efficiencyReq : Definitions::EfficiencyRequirement {
                subject pump = pumpingSystem.rotaryPump;
            }
            
            satisfy reliabilityReq : Definitions::ReliabilityRequirement {
                subject subsystem = pumpingSystem;
            }
            
            assert constraint suctionPressureLimit {
                rotaryPump.suctionPort.inletPressure >= -0.5 and
                rotaryPump.suctionPort.inletPressure <= 1.5
            }
            
            assert constraint dischargePressureRange {
                rotaryPump.dischargePort.outletPressure >= 5.0 and
                rotaryPump.dischargePort.outletPressure <= rotaryPump.maxPressure
            }
            
            assert constraint motorPowerAdequacy {
                driveMotor.ratedPower >= 
                    (rotaryPump.dischargePort.outletPressure * rotaryPump.dischargePort.outletFlowRate) / 
                    (rotaryPump.volumetricEfficiency * rotaryPump.mechanicalEfficiency * driveMotor.motorEfficiency)
            }
            
            assert constraint reservoirLevelMonitoring {
                sourceReservoir.currentLevel >= sourceReservoir.minLevel
            }
        }
    }
}
