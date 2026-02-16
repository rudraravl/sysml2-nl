package VoluteSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FlowRate :> ISQ::VolumeFlowRateValue {
        attribute :>> num : Real;
        attribute :>> mRef : VolumeFlowRateUnit;
    }
    
    attribute def Pressure :> ISQ::PressureValue {
        attribute :>> num : Real;
        attribute :>> mRef : PressureUnit;
    }
    
    attribute def Velocity :> ISQ::SpeedValue {
        attribute :>> num : Real;
        attribute :>> mRef : SpeedUnit;
    }
    
    attribute def RotationalSpeed :> ISQ::AngularVelocityValue {
        attribute :>> num : Real;
        attribute :>> mRef : AngularVelocityUnit;
    }
    
    attribute def Efficiency :> Real;
    
    item def Fluid {
        attribute density : ISQ::DensityValue;
        attribute viscosity : ISQ::DynamicViscosityValue;
    }
    
    port def FluidPort {
        in attribute pressure : Pressure;
        in attribute flowRate : FlowRate;
        in attribute velocity : Velocity;
    }
    
    port def RotationalPort {
        in attribute speed : RotationalSpeed;
        in attribute torque : ISQ::TorqueValue;
    }
    
    part def Impeller {
        doc /* Rotating component that imparts kinetic energy to the fluid through centrifugal force. */
        
        attribute bladeCount : Integer;
        attribute outerDiameter : ISQ::LengthValue;
        attribute inletDiameter : ISQ::LengthValue;
        
        port shaftInput : RotationalPort;
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        
        action def AccelerateFluid {
            in rotSpeed : RotationalSpeed;
            in inletFlow : FlowRate;
            in inletPressure : Pressure;
            out outletVelocity : Velocity;
            out outletFlow : FlowRate;
            out kineticEnergy : ISQ::EnergyValue;
        }
    }
    
    part def VoluteCasing {
        doc /* Spiral-shaped casing that progressively converts high-velocity fluid from the impeller into static pressure through gradual deceleration. */
        
        attribute spiralAngle : Real;
        attribute inletArea : ISQ::AreaValue;
        attribute outletArea : ISQ::AreaValue;
        attribute tongueAngle : Real;
        
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        
        action def ConvertVelocityToPressure {
            in inletVelocity : Velocity;
            in inletPressure : Pressure;
            in inletFlow : FlowRate;
            out outletPressure : Pressure;
            out outletVelocity : Velocity;
            out outletFlow : FlowRate;
            out pressureRise : Pressure;
        }
    }
    
    part def DischargePipe {
        doc /* Outlet conduit that delivers pressurized fluid to the system discharge point. */
        
        attribute diameter : ISQ::LengthValue;
        attribute length : ISQ::LengthValue;
        
        port inlet : FluidPort;
        port outlet : FluidPort;
    }
    
    connection def FluidConnection {
        end source : FluidPort;
        end target : FluidPort;
    }
    
    connection def MechanicalConnection {
        end source : RotationalPort;
        end target : RotationalPort;
    }
    
    part def VolutePumpSystem {
        doc /* A centrifugal pump system utilizing a volute casing to convert rotational mechanical energy into fluid pressure and flow by accelerating fluid radially outward through an impeller and then progressively decelerating it in an expanding spiral chamber to recover static pressure. */
        
        attribute designFlowRate : FlowRate;
        attribute designPressureRise : Pressure;
        attribute designSpeed : RotationalSpeed;
        attribute hydraulicEfficiency : Efficiency;
        
        port driveShaft : RotationalPort;
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        
        part impeller : Impeller {
            attribute :>> bladeCount = 6;
            attribute :>> outerDiameter = 300.0 [SI::mm];
            attribute :>> inletDiameter = 100.0 [SI::mm];
        }
        
        part volute : VoluteCasing {
            attribute :>> spiralAngle = 7.5;
            attribute :>> inletArea = 0.025 [SI::m^2];
            attribute :>> outletArea = 0.008 [SI::m^2];
            attribute :>> tongueAngle = 15.0;
        }
        
        part dischargePipe : DischargePipe {
            attribute :>> diameter = 80.0 [SI::mm];
            attribute :>> length = 500.0 [SI::mm];
        }
        
        connection driveConnection : MechanicalConnection connect driveShaft to impeller.shaftInput;
        connection suctionConnection : FluidConnection connect suctionPort to impeller.fluidInlet;
        connection impellerToVolute : FluidConnection connect impeller.fluidOutlet to volute.fluidInlet;
        connection voluteToDischarge : FluidConnection connect volute.fluidOutlet to dischargePipe.inlet;
        connection dischargeConnection : FluidConnection connect dischargePipe.outlet to dischargePort;
        
        perform action pumpOperation : PumpFluid;
    }
    
    action def PumpFluid {
        doc /* Primary pumping operation that converts rotational energy into fluid pressure through sequential acceleration and controlled deceleration. */
        
        in shaftSpeed : RotationalSpeed;
        in suctionPressure : Pressure;
        in suctionFlow : FlowRate;
        out dischargePressure : Pressure;
        out dischargeFlow : FlowRate;
        out totalPressureRise : Pressure;
        
        first start;
        then action accelerate : Impeller::AccelerateFluid {
            in rotSpeed = shaftSpeed;
            in inletFlow = suctionFlow;
            in inletPressure = suctionPressure;
            out outletVelocity;
            out outletFlow;
            out kineticEnergy;
        }
        then action convertPressure : VoluteCasing::ConvertVelocityToPressure {
            in inletVelocity = accelerate.outletVelocity;
            in inletPressure = suctionPressure;
            in inletFlow = accelerate.outletFlow;
            out outletPressure;
            out outletVelocity;
            out outletFlow;
            out pressureRise;
        }
        then assign dischargeFlow := convertPressure.outletFlow;
        then assign dischargePressure := convertPressure.outletPressure;
        then assign totalPressureRise := dischargePressure - suctionPressure;
        then done;
    }
    
    state def PumpOperationalStates {
        entry; then stopped;
        
        state stopped {
            entry assign currentSpeed := 0.0 [SI::'rad/s'];
        }
        
        transition stopped_to_starting
            first stopped
            accept StartCommand
            then starting;
        
        state starting {
            entry action rampUp {
                in targetSpeed : RotationalSpeed;
                out achievedSpeed : RotationalSpeed;
            }
        }
        
        transition starting_to_running
            first starting
            if currentSpeed >= nominalSpeed
            then running;
        
        state running {
            do action continuousPumping : PumpFluid;
            
            state normalOperation;
            state cavitationDetected;
            
            transition normal_to_cavitation
                first normalOperation
                if suctionPressure < vaporPressure
                then cavitationDetected;
            
            transition cavitation_to_normal
                first cavitationDetected
                if suctionPressure >= vaporPressure
                then normalOperation;
        }
        
        transition running_to_stopping
            first running
            accept StopCommand
            then stopping;
        
        state stopping {
            entry action coastDown {
                out finalSpeed : RotationalSpeed;
            }
        }
        
        transition stopping_to_stopped
            first stopping
            if currentSpeed <= 0.0 [SI::'rad/s']
            then stopped;
        
        attribute currentSpeed : RotationalSpeed;
        attribute nominalSpeed : RotationalSpeed;
        attribute suctionPressure : Pressure;
        attribute vaporPressure : Pressure;
    }
    
    attribute def StartCommand;
    attribute def StopCommand;
    
    requirement def VolutePumpRequirements {
        doc /* Performance and operational requirements for the volute pump system. */
        
        subject pumpSystem : VolutePumpSystem;
        
        requirement flowCapabilityRequirement {
            doc /* The pump shall deliver the design flow rate at the specified operating speed with tolerance of +/- 5%. */
            
            assume constraint { pumpSystem.driveShaft.speed >= 0.95 * pumpSystem.designSpeed }
            require constraint { 
                pumpSystem.dischargePort.flowRate >= 0.95 * pumpSystem.designFlowRate and
                pumpSystem.dischargePort.flowRate <= 1.05 * pumpSystem.designFlowRate
            }
        }
        
        requirement pressureRiseRequirement {
            doc /* The pump shall achieve the design pressure rise between suction and discharge at design flow conditions. */
            
            require constraint {
                pumpSystem.dischargePort.pressure - pumpSystem.suctionPort.pressure >= 0.90 * pumpSystem.designPressureRise
            }
        }
        
        requirement efficiencyRequirement {
            doc /* The pump shall operate at minimum 72% hydraulic efficiency at design point. */
            
            require constraint { pumpSystem.hydraulicEfficiency >= 0.72 }
        }
        
        requirement voluteGeometryRequirement {
            doc /* The volute casing shall provide progressive area expansion to enable efficient velocity-to-pressure conversion. */
            
            require constraint { 
                pumpSystem.volute.outletArea < pumpSystem.volute.inletArea
            }
        }
    }
    
    part volutePumpInstance : VolutePumpSystem {
        attribute :>> designFlowRate = 150.0 [SI::L/SI::min];
        attribute :>> designPressureRise = 300.0 [SI::kPa];
        attribute :>> designSpeed = 183.26 [SI::'rad/s'];
        attribute :>> hydraulicEfficiency = 0.76;
    }
    
    requirement systemRequirements : VolutePumpRequirements {
        subject pumpSystem = volutePumpInstance;
    }
}
