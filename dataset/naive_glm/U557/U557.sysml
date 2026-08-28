package RushtonTurbineMixingSystem {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceAndTime::*;
    import ISQMechanics::*;

    // ---- Value types with units ----
    def package ValueTypeDefinitions {
        attribute def RotationalSpeed :> Real { unit = "rad/s"; }
        attribute def Power :> Real { unit = "W"; }
        attribute def Torque :> Real { unit = "N*m"; }
        attribute def Volume :> Real { unit = "m^3"; }
        attribute def Length :> Real { unit = "m"; }
        attribute def Diameter :> Real { unit = "m"; }
        attribute def Velocity :> Real { unit = "m/s"; }
        attribute def ReynoldsNumber :> Real { unit = "1"; }
        attribute def MixingTime :> Real { unit = "s"; }
        attribute def Temperature :> Real { unit = "K"; }
        attribute def Density :> Real { unit = "kg/m^3"; }
        attribute def Viscosity :> Real { unit = "Pa*s"; }
    }

    // ---- Item types ----
    item def FluidComponent {
        attribute density : Density;
        attribute viscosity : Viscosity;
        attribute temperature : Temperature;
    }

    item def MixedFluid :> FluidComponent {
        attribute homogeneity : Real; // 0 to 1
    }

    item def ElectricPower {
        attribute voltage : Real { unit = "V"; }
        attribute current : Real { unit = "A"; }
        attribute frequency : Real { unit = "Hz"; }
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute targetSpeed : RotationalSpeed;
    }

    item def MechanicalTorque {
        attribute magnitude : Torque;
        attribute speed : RotationalSpeed;
    }

    item def RadialFlow {
        attribute velocity : Velocity;
        attribute flowRate : Real { unit = "m^3/s"; }
    }

    item def CirculationLoop {
        attribute direction : String;
        attribute volumeTurnover : Real { unit = "m^3/s"; }
    }

    // ---- Port definitions ----
    port def PowerPort {
        out electricPower : ElectricPower;
    }

    port def MechanicalPort {
        out torque : MechanicalTorque;
    }

    port def FluidPort {
        out fluid : MixedFluid;
    }

    port def ControlPort {
        in command : ControlCommand;
    }

    port def FlowPort {
        out radialFlow : RadialFlow;
        in circulation : CirculationLoop;
    }

    // ---- Parts ----
    part def MixingVessel {
        attribute diameter : Diameter = 2.0;
        attribute height : Length = 3.0;
        attribute totalVolume : Volume = 9.42;
        attribute wallThickness : Length = 0.01;
        
        port fluidOut : FluidPort;
        port flowInteraction : FlowPort;
        
        part vesselWall {
            attribute material : String = "Stainless Steel 316L";
        }
        
        part vesselBottom {
            attribute shape : String = "Dished";
        }
        
        part vesselSurface {
            attribute level : Length = 2.4;
        }
    }

    part def Baffle {
        attribute width : Length = 0.2;
        attribute thickness : Length = 0.02;
        attribute height : Length = 2.4;
        attribute position : Integer; // 1 to 4
        attribute material : String = "Stainless Steel 316L";
        
        attribute deflectionEfficiency : Real = 0.85;
    }

    part def ElectricMotor {
        attribute ratedPower : Power = 7500.0;
        attribute ratedSpeed : RotationalSpeed = 10.47; // 100 rpm
        attribute efficiency : Real = 0.92;
        attribute supplyVoltage : Real { unit = "V"; } = 400.0;
        attribute supplyFrequency : Real { unit = "Hz"; } = 50.0;
        
        port powerIn : PowerPort;
        port mechanicalOut : MechanicalPort;
        port controlIn : ControlPort;
        
        attribute currentSpeed : RotationalSpeed;
        attribute currentTorque : Torque;
        attribute currentPower : Power;
        
        action generateTorque {
            in speed : RotationalSpeed;
            out torque : MechanicalTorque;
        }
    }

    part def DriveShaft {
        attribute length : Length = 3.5;
        attribute diameter : Diameter = 0.06;
        attribute material : String = "Stainless Steel 316L";
        attribute maxTorque : Torque = 500.0;
        
        port mechanicalIn : MechanicalPort;
        port mechanicalOut : MechanicalPort;
        
        attribute deflection : Length = 0.001;
        attribute criticalSpeed : RotationalSpeed = 52.36;
        
        action transmitTorque {
            in inputTorque : MechanicalTorque;
            out outputTorque : MechanicalTorque;
        }
    }

    part def RushtonImpeller {
        attribute diskDiameter : Diameter = 0.25;
        attribute bladeCount : Integer = 6;
        attribute bladeHeight : Length = 0.05;
        attribute bladeWidth : Length = 0.05;
        attribute bladeThickness : Length = 0.003;
        attribute material : String = "Stainless Steel 316L";
        attribute powerNumber : Real = 5.0;
        attribute flowNumber : Real = 0.72;
        
        port mechanicalIn : MechanicalPort;
        port flowOut : FlowPort;
        
        attribute tipSpeed : Velocity;
        attribute reynoldsNumber : ReynoldsNumber;
        
        action generateRadialFlow {
            in torque : MechanicalTorque;
            out radialFlow : RadialFlow;
            out circulation : CirculationLoop[2];
        }
    }

    part def BaffleAssembly {
        part baffle1 : Baffle { attribute position = 1; }
        part baffle2 : Baffle { attribute position = 2; }
        part baffle3 : Baffle { attribute position = 3; }
        part baffle4 : Baffle { attribute position = 4; }
    }

    part def MixingSystem {
        attribute systemId : String = "RTMS-001";
        attribute targetSpeed : RotationalSpeed = 10.47;
        attribute operatingTemperature : Temperature = 298.15;
        
        port controlIn : ControlPort;
        port fluidOut : FluidPort;
        
        part vessel : MixingVessel;
        part baffles : BaffleAssembly;
        part motor : ElectricMotor;
        part shaft : DriveShaft;
        part impeller : RushtonImpeller;
        
        connection motorToShaft connect motor.mechanicalOut to shaft.mechanicalIn;
        connection shaftToImpeller connect shaft.mechanicalOut to impeller.mechanicalIn;
        connection impellerToVessel connect impeller.flowOut to vessel.flowInteraction;
        
        // State machine for system operation
        state def SystemStates {
            attribute currentSpeed : RotationalSpeed;
            
            state Idle {
                entry action {
                    currentSpeed = 0.0;
                }
            }
            
            state Starting {
                entry action {
                    currentSpeed = 0.0;
                }
                do action rampUp {
                    // Ramp speed up to target
                    currentSpeed = targetSpeed;
                }
            }
            
            state Running {
                entry action {
                    currentSpeed = targetSpeed;
                }
                do action maintainOperation {
                    // Maintain target rotational speed
                    // Generate radial flow
                    // Sustain circulation loops
                }
            }
            
            state Stopping {
                entry action {
                    // Begin spin down
                }
                do action rampDown {
                    currentSpeed = 0.0;
                }
            }
            
            transition Idle_to_Starting first Idle then Starting
                when controlIn.command.commandType == "START";
            
            transition Starting_to_Running first Starting then Running
                when currentSpeed >= targetSpeed;
            
            transition Running_to_Stopping first Running then Stopping
                when controlIn.command.commandType == "STOP";
            
            transition Stopping_to_Idle first Stopping then Idle
                when currentSpeed <= 0.0;
        }
        
        part systemController {
            port control : ControlPort;
            attribute stateMachine : SystemStates;
            
            action processCommand {
                in cmd : ControlCommand;
                // Process start/stop commands
            }
        }
    }

    // ---- Requirements ----
    requirement def MixingPerformanceRequirement {
        attribute minHomogeneity : Real = 0.95;
        attribute maxMixingTime : MixingTime = 300.0;
        
        subject mixingSystem : MixingSystem;
        
        require {
            doc /* The mixing system shall achieve a homogeneity of at least 95% within 300 seconds of operation. */
        }
    }

    requirement def TurbulenceRequirement {
        attribute minReynoldsNumber : ReynoldsNumber = 10000.0;
        
        subject impeller : RushtonImpeller;
        
        require {
            doc /* The impeller shall generate turbulent flow with Reynolds number above 10,000 during operation. */
        }
    }

    requirement def CirculationRequirement {
        attribute minTurnoverRate : Real { unit = "m^3/s"; } = 0.5;
        
        subject vessel : MixingVessel;
        
        require {
            doc /* The system shall maintain a minimum fluid turnover rate of 0.5 m^3/s during operation. */
        }
    }

    requirement def PowerRequirement {
        attribute maxPowerConsumption : Power = 7500.0;
        
        subject motor : ElectricMotor;
        
        require {
            doc /* The motor shall not exceed 7500 W power consumption during normal operation. */
        }
    }

    requirement def StructuralIntegrityRequirement {
        attribute maxShaftDeflection : Length = 0.002;
        attribute maxBaffleStress : Real { unit = "Pa"; } = 150000000.0;
        
        subject system : MixingSystem;
        
        require {
            doc /* The drive shaft deflection shall not exceed 2 mm and baffle stress shall not exceed 150 MPa. */
        }
    }

    requirement def SpeedControlRequirement {
        attribute targetSpeed : RotationalSpeed = 10.47;
        attribute speedTolerance : RotationalSpeed = 0.52;
        
        subject controller : MixingSystem::systemController;
        
        require {
            doc /* The system shall maintain rotational speed within 5% of target during Running state. */
        }
    }

    // ---- Verification actions ----
    action def VerifyMixingPerformance {
        in mixingSystem : MixingSystem;
        in performanceReq : MixingPerformanceRequirement;
        out result : Boolean;
        
        // Verify homogeneity and mixing time
    }

    action def VerifyTurbulence {
        in impeller : RushtonImpeller;
        in turbulenceReq : TurbulenceRequirement;
        out result : Boolean;
        
        // Verify Reynolds number exceeds threshold
    }

    action def VerifyCirculation {
        in vessel : MixingVessel;
        in circulationReq : CirculationRequirement;
        out result : Boolean;
        
        // Verify turnover rate
    }

    // ---- Top-level package composition ----
    package SystemInstances {
        part mixingSystemInstance : MixingSystem {
            attribute systemId = "RTMS-001";
            
            part vessel {
                attribute diameter = 2.0;
                attribute height = 3.0;
                attribute totalVolume = 9.42;
            }
            
            part baffles {
                part baffle1 { attribute position = 1; }
                part baffle2 { attribute position = 2; }
                part baffle3 { attribute position = 3; }
                part baffle4 { attribute position = 4; }
            }
            
            part motor {
                attribute ratedPower = 7500.0;
                attribute ratedSpeed = 10.47;
                attribute efficiency = 0.92;
            }
            
            part shaft {
                attribute length = 3.5;
                attribute diameter = 0.06;
            }
            
            part impeller {
                attribute diskDiameter = 0.25;
                attribute bladeCount = 6;
                attribute bladeHeight = 0.05;
                attribute bladeWidth = 0.05;
            }
        }
        
        requirement satisfaction {
            subject mixingSystemInstance;
            satisfy MixingPerformanceRequirement;
            satisfy TurbulenceRequirement;
            satisfy CirculationRequirement;
            satisfy PowerRequirement;
            satisfy StructuralIntegrityRequirement;
            satisfy SpeedControlRequirement;
        }
    }
}
