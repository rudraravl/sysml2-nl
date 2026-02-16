package ProgressingCavityPumpingSubsystem {
    private import ScalarValues::*;
    
    package Definitions {
        attribute def ViscosityUnit;
        attribute def DensityUnit;
        attribute def TemperatureUnit;
        attribute def PressureUnit;
        attribute def VolumeFlowRateUnit;
        attribute def RotationalSpeedUnit;
        attribute def TorqueUnit;
        attribute def PowerUnit;
        attribute def LengthUnit;
        
        attribute def ViscosityValue :> Real {
            attribute unit : ViscosityUnit;
        }
        
        attribute def DensityValue :> Real {
            attribute unit : DensityUnit;
        }
        
        attribute def TemperatureValue :> Real {
            attribute unit : TemperatureUnit;
        }
        
        attribute def PressureValue :> Real {
            attribute unit : PressureUnit;
        }
        
        attribute def VolumeFlowRateValue :> Real {
            attribute unit : VolumeFlowRateUnit;
        }
        
        attribute def RotationalSpeedValue :> Real {
            attribute unit : RotationalSpeedUnit;
        }
        
        attribute def TorqueValue :> Real {
            attribute unit : TorqueUnit;
        }
        
        attribute def PowerValue :> Real {
            attribute unit : PowerUnit;
        }
        
        attribute def LengthValue :> Real {
            attribute unit : LengthUnit;
        }
        
        item def Fluid {
            attribute viscosity : ViscosityValue;
            attribute density : DensityValue;
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute volumeFlowRate : VolumeFlowRateValue;
        }
        
        port def FluidPort {
            in item fluidIn : Fluid;
            out item fluidOut : Fluid;
            attribute portPressure : PressureValue;
            attribute portTemperature : TemperatureValue;
        }
        
        port def MechanicalPort {
            attribute rotationalSpeed : RotationalSpeedValue;
            attribute torque : TorqueValue;
        }
        
        port def ElectricalPort {
            attribute voltage : Real;
            attribute current : Real;
            attribute power : PowerValue;
        }
        
        part def Rotor {
            attribute helixPitch : LengthValue;
            attribute eccentricity : LengthValue;
            attribute diameter : LengthValue;
            attribute length : LengthValue;
            attribute numberOfStages : Integer;
            attribute rotationalSpeed : RotationalSpeedValue;
            port mechanicalPort : MechanicalPort;
        }
        
        part def Stator {
            attribute internalHelixPitch : LengthValue;
            attribute cavityDiameter : LengthValue;
            attribute length : LengthValue;
            attribute numberOfLobes : Integer;
            attribute material : String;
        }
        
        part def Seal {
            attribute material : String;
            attribute maxTemperature : TemperatureValue;
            attribute maxPressure : PressureValue;
        }
        
        part def DriveshaftAssembly {
            attribute diameter : LengthValue;
            attribute length : LengthValue;
            attribute maxTorque : TorqueValue;
            attribute material : String;
        }
        
        part def ProgressingCavityPump {
            attribute nominalFlowRate : VolumeFlowRateValue;
            attribute maxDischargePressure : PressureValue;
            attribute nominalSpeed : RotationalSpeedValue;
            attribute efficiency : Real;
            attribute displacementPerRevolution : Real;
            attribute currentPumpSpeed : Real;
            attribute targetOperatingSpeed : Real;
            attribute minPressureDifferential : Real;
            
            port suctionPort : ~FluidPort;
            port dischargePort : FluidPort;
            port drivePort : ~MechanicalPort;
            
            part rotor : Rotor {
                attribute :>> helixPitch : LengthValue;
                attribute :>> eccentricity : LengthValue;
                attribute :>> diameter : LengthValue;
                attribute :>> length : LengthValue;
                attribute :>> numberOfStages = 4;
            }
            
            part stator : Stator {
                attribute :>> internalHelixPitch : LengthValue;
                attribute :>> cavityDiameter : LengthValue;
                attribute :>> length : LengthValue;
                attribute :>> numberOfLobes = 2;
                attribute :>> material = "Elastomer";
            }
            
            part suctionSeal : Seal {
                attribute :>> material = "Nitrile";
                attribute :>> maxTemperature : TemperatureValue;
                attribute :>> maxPressure : PressureValue;
            }
            
            part dischargeSeal : Seal {
                attribute :>> material = "Viton";
                attribute :>> maxTemperature : TemperatureValue;
                attribute :>> maxPressure : PressureValue;
            }
            
            part driveshaft : DriveshaftAssembly {
                attribute :>> diameter : LengthValue;
                attribute :>> length : LengthValue;
                attribute :>> maxTorque : TorqueValue;
                attribute :>> material = "Stainless Steel 316";
            }
            
            connect rotor.mechanicalPort to drivePort;
            
            action def PumpFluid {
                in fluidIn : Fluid;
                in speed : RotationalSpeedValue;
                out fluidOut : Fluid;
                out flowRate : VolumeFlowRateValue;
                out pressureRise : PressureValue;
            }
        }
        
        part def ElectricMotor {
            attribute ratedPower : PowerValue;
            attribute ratedSpeed : RotationalSpeedValue;
            attribute efficiency : Real;
            attribute motorType : String;
            attribute currentSpeed : RotationalSpeedValue;
            
            port powerInput : ~ElectricalPort;
            port mechanicalOutput : MechanicalPort;
            
            action def SetSpeed {
                in targetSpeed : RotationalSpeedValue;
                out actualSpeed : RotationalSpeedValue;
            }
        }
        
        part def VariableFrequencyDrive {
            attribute inputVoltage : Real;
            attribute outputFrequency : Real;
            attribute maxCurrent : Real;
            attribute currentFrequency : Real;
            
            port powerIn : ~ElectricalPort;
            port powerOut : ElectricalPort;
            
            action def AdjustFrequency {
                in targetFrequency : Real;
                out actualFrequency : Real;
            }
        }
        
        part def SupplyReservoir {
            attribute capacity : Real;
            attribute currentLevel : Real;
            attribute minLevel : Real;
            attribute maxLevel : Real;
            
            port outletPort : FluidPort;
            
            item storedFluid : Fluid {
                attribute :>> viscosity : ViscosityValue;
                attribute :>> density : DensityValue;
                attribute :>> temperature : TemperatureValue;
                attribute :>> pressure : PressureValue;
            }
        }
        
        part def DischargeVessel {
            attribute capacity : Real;
            attribute currentLevel : Real;
            attribute maxPressure : PressureValue;
            attribute currentPressure : PressureValue;
            
            port inletPort : ~FluidPort;
            
            item receivedFluid : Fluid;
        }
        
        part def PressureSensor {
            attribute reading : PressureValue;
            attribute accuracy : Real;
            attribute range : PressureValue;
            port sensingPort : ~FluidPort;
        }
        
        part def FlowMeter {
            attribute flowReading : VolumeFlowRateValue;
            attribute accuracy : Real;
            attribute range : VolumeFlowRateValue;
            port measurementPort : ~FluidPort;
        }
        
        part def TemperatureSensor {
            attribute reading : TemperatureValue;
            attribute accuracy : Real;
            port sensingPort : ~FluidPort;
        }
        
        action def StartPumpAction {
            in targetSpeed : RotationalSpeedValue;
            out actualSpeed : RotationalSpeedValue;
        }
        
        action def StopPumpAction {
            in currentSpeed : RotationalSpeedValue;
            out finalSpeed : RotationalSpeedValue;
        }
        
        action def AdjustFlowRate {
            in desiredFlowRate : VolumeFlowRateValue;
            in currentFlowRate : VolumeFlowRateValue;
            out adjustedSpeed : RotationalSpeedValue;
        }
        
        action def MonitorPressure {
            in suctionPressure : PressureValue;
            in dischargePressure : PressureValue;
            out pressureDifferential : PressureValue;
        }
        
        action def CheckCavitation {
            in suctionPressure : PressureValue;
            in fluidVaporPressure : PressureValue;
            out cavitationRisk : Boolean;
        }
        
        action def ReducePressureAction;
        
        state def PumpOperatingStates {
            entry; then idle;
            
            state idle;
            
            transition idle_to_priming
                first idle
                accept PrimeCommand
                then priming;
            
            state priming;
            
            transition priming_to_starting
                first priming
                accept StartCommand
                then starting;
            
            transition priming_to_idle
                first priming
                accept AbortCommand
                then idle;
            
            state starting;
            
            transition starting_to_running
                first starting
                accept RunningReached
                then running;
            
            state running {
                state normalOperation;
                
                state adjustingFlow;
                
                state cavitationDetected;
                
                transition normal_to_adjusting
                    first normalOperation
                    accept FlowAdjustmentRequest
                    then adjustingFlow;
                
                transition adjusting_to_normal
                    first adjustingFlow
                    accept AdjustmentComplete
                    then normalOperation;
                
                transition normal_to_cavitation
                    first normalOperation
                    accept CavitationDetected
                    then cavitationDetected;
                
                transition cavitation_to_normal
                    first cavitationDetected
                    accept CavitationCleared
                    then normalOperation;
            }
            
            transition running_to_stopping
                first running
                accept StopCommand
                then stopping;
            
            state stopping;
            
            transition stopping_to_idle
                first stopping
                accept StoppedReached
                then idle;
            
            transition any_to_emergency
                first idle, priming, starting, running, stopping
                accept EmergencyStop
                then emergencyStop;
            
            state emergencyStop;
            
            transition emergency_to_idle
                first emergencyStop
                accept ResetCommand
                then idle;
        }
    }
    
    package Usages {
        part progressingCavityPumpingSystem {
            part supplyReservoir : Definitions::SupplyReservoir {
                attribute :>> capacity = 5000.0;
                attribute :>> currentLevel = 4200.0;
                attribute :>> minLevel = 500.0;
                attribute :>> maxLevel = 4800.0;
                
                item :>> storedFluid {
                    attribute :>> viscosity : Definitions::ViscosityValue;
                    attribute :>> density : Definitions::DensityValue;
                    attribute :>> temperature : Definitions::TemperatureValue;
                    attribute :>> pressure : Definitions::PressureValue;
                }
            }
            
            part suctionPressureSensor : Definitions::PressureSensor {
                attribute :>> accuracy = 0.5;
                attribute :>> range : Definitions::PressureValue;
            }
            
            part suctionTemperatureSensor : Definitions::TemperatureSensor {
                attribute :>> accuracy = 0.2;
            }
            
            flow of fluid : Definitions::Fluid
                from supplyReservoir.outletPort.fluidOut 
                to suctionPressureSensor.sensingPort.fluidIn;
            
            flow of fluid : Definitions::Fluid
                from suctionPressureSensor.sensingPort.fluidOut 
                to suctionTemperatureSensor.sensingPort.fluidIn;
            
            part pcPump : Definitions::ProgressingCavityPump {
                attribute :>> nominalFlowRate : Definitions::VolumeFlowRateValue;
                attribute :>> maxDischargePressure : Definitions::PressureValue;
                attribute :>> nominalSpeed : Definitions::RotationalSpeedValue;
                attribute :>> efficiency = 0.85;
                attribute :>> displacementPerRevolution = 0.02;
                attribute :>> currentPumpSpeed = 0.0;
                attribute :>> targetOperatingSpeed = 500.0;
                attribute :>> minPressureDifferential = 50000.0;
                
                perform action pumpFluid : PumpFluid {
                    in fluidIn = suctionPort.fluidIn;
                    in speed = rotor.rotationalSpeed;
                    out fluidOut = dischargePort.fluidOut;
                    out flowRate : Definitions::VolumeFlowRateValue;
                    out pressureRise : Definitions::PressureValue;
                }
                
                perform state pumpOperation : Definitions::PumpOperatingStates;
            }
            
            flow of fluid : Definitions::Fluid
                from suctionTemperatureSensor.sensingPort.fluidOut 
                to pcPump.suctionPort.fluidIn;
            
            part dischargePressureSensor : Definitions::PressureSensor {
                attribute :>> accuracy = 0.5;
                attribute :>> range : Definitions::PressureValue;
            }
            
            flow of fluid : Definitions::Fluid
                from pcPump.dischargePort.fluidOut 
                to dischargePressureSensor.sensingPort.fluidIn;
            
            part dischargeFlowMeter : Definitions::FlowMeter {
                attribute :>> accuracy = 1.0;
                attribute :>> range : Definitions::VolumeFlowRateValue;
            }
            
            flow of fluid : Definitions::Fluid
                from dischargePressureSensor.sensingPort.fluidOut 
                to dischargeFlowMeter.measurementPort.fluidIn;
            
            part dischargeTemperatureSensor : Definitions::TemperatureSensor {
                attribute :>> accuracy = 0.2;
            }
            
            flow of fluid : Definitions::Fluid
                from dischargeFlowMeter.measurementPort.fluidOut 
                to dischargeTemperatureSensor.sensingPort.fluidIn;
            
            part dischargeVessel : Definitions::DischargeVessel {
                attribute :>> capacity = 3000.0;
                attribute :>> currentLevel = 800.0;
                attribute :>> maxPressure : Definitions::PressureValue;
                attribute :>> currentPressure : Definitions::PressureValue;
            }
            
            flow of fluid : Definitions::Fluid
                from dischargeTemperatureSensor.sensingPort.fluidOut 
                to dischargeVessel.inletPort.fluidIn;
            
            part vfd : Definitions::VariableFrequencyDrive {
                attribute :>> inputVoltage = 480.0;
                attribute :>> outputFrequency = 60.0;
                attribute :>> maxCurrent = 50.0;
                attribute :>> currentFrequency = 60.0;
            }
            
            part driveMotor : Definitions::ElectricMotor {
                attribute :>> ratedPower : Definitions::PowerValue;
                attribute :>> ratedSpeed : Definitions::RotationalSpeedValue;
                attribute :>> efficiency = 0.92;
                attribute :>> motorType = "Three-phase induction";
                attribute :>> currentSpeed : Definitions::RotationalSpeedValue;
            }
            
            connect vfd.powerOut to driveMotor.powerInput;
            connect driveMotor.mechanicalOutput to pcPump.drivePort;
            
            perform action monitorSystem : Definitions::MonitorPressure {
                in suctionPressure = suctionPressureSensor.reading;
                in dischargePressure = dischargePressureSensor.reading;
                out pressureDifferential : Definitions::PressureValue;
            }
            
            perform action checkCavitation : Definitions::CheckCavitation {
                in suctionPressure = suctionPressureSensor.reading;
                in fluidVaporPressure : Definitions::PressureValue;
                out cavitationRisk : Boolean;
            }
        }
    }
    
    package Requirements {
        requirement def FlowCapabilityRequirement {
            doc /* The progressing cavity pump shall deliver fluid at the specified nominal 
                   flow rate with acceptable tolerance under normal operating conditions. */
            
            subject pump : Definitions::ProgressingCavityPump;
            
            attribute minFlowRate : Real = 8.0;
            attribute maxFlowRate : Real = 12.0;
        }
        
        requirement def PressureCapabilityRequirement {
            doc /* The pump shall withstand and operate at discharge pressures up to the 
                   maximum rated pressure without failure or performance degradation. */
            
            subject pump : Definitions::ProgressingCavityPump;
            
            attribute minPressure : Real = 1000000.0;
        }
        
        requirement def ViscosityHandlingRequirement {
            doc /* The progressing cavity pump shall handle fluids with viscosity ranging 
                   from low to high without cavitation or loss of prime. */
            
            subject pump : Definitions::ProgressingCavityPump;
            subject fluid : Definitions::Fluid;
            
            attribute minViscosity : Real = 1.0;
            attribute maxViscosity : Real = 1000.0;
        }
        
        requirement def EfficiencyRequirement {
            doc /* The pump system shall operate at minimum efficiency to ensure 
                   energy-effective fluid transfer. */
            
            subject pump : Definitions::ProgressingCavityPump;
            
            attribute minEfficiency : Real = 0.80;
            
            require constraint {
                pump.efficiency >= minEfficiency
            }
        }
        
        requirement def SafetyRequirement {
            doc /* The pumping system shall include emergency stop capability that 
                   immediately halts pump operation when activated. */
            
            subject pumpState : Definitions::PumpOperatingStates;
        }
        
        requirement def CavitationPreventionRequirement {
            doc /* The system shall monitor suction pressure and prevent cavitation by 
                   maintaining adequate net positive suction head. */
            
            subject system : Usages::progressingCavityPumpingSystem;
            
            attribute minNPSH : Real = 50000.0;
        }
        
        requirement flowCapability : FlowCapabilityRequirement {
            subject pump = Usages::progressingCavityPumpingSystem.pcPump;
        }
        
        requirement pressureCapability : PressureCapabilityRequirement {
            subject pump = Usages::progressingCavityPumpingSystem.pcPump;
        }
        
        requirement viscosityHandling : ViscosityHandlingRequirement {
            subject pump = Usages::progressingCavityPumpingSystem.pcPump;
            subject fluid = Usages::progressingCavityPumpingSystem.supplyReservoir.storedFluid;
        }
        
        requirement efficiency : EfficiencyRequirement {
            subject pump = Usages::progressingCavityPumpingSystem.pcPump;
        }
        
        requirement safety : SafetyRequirement {
            subject pumpState = Usages::progressingCavityPumpingSystem.pcPump.pumpOperation;
        }
        
        requirement cavitationPrevention : CavitationPreventionRequirement {
            subject system = Usages::progressingCavityPumpingSystem;
        }
    }
}
