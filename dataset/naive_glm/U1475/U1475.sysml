package PropulsionSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQEnergy::*;
    import ISQForce::*;
    import ISQElectricity::*;
    import ISQMechanics::*;

    // ---- Value types with units ----
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def ElectricalPower :> Real { unit 'W'; }
    value def Torque :> Real { unit 'N*m'; }
    value def RotationalSpeed :> Real { unit 'rpm'; }
    value def ThrustForce :> Real { unit 'N'; }
    value def MechanicalPower :> Real { unit 'W'; }
    value def Diameter :> Length;
    value def BladeStress :> Real { unit 'Pa'; }
    value def MassFlowRate :> Real { unit 'kg/s'; }
    value def AirSpeed :> Speed;
    value def ControlCommand :> Real { unit '1'; }  // normalized 0..1

    // ---- Item types ----
    item def ElectricalEnergy;
    item def ControlInput;
    item def RotationalMechanicalEnergy;
    item def Airflow;

    // ---- Port definitions ----
    port def ElectricalPowerPort {
        attribute voltage : Voltage;
        attribute current : Current;
        out item energy : ElectricalEnergy;
    }

    port def ControlPort {
        in item command : ControlInput;
        attribute throttle : ControlCommand;
    }

    port def MechanicalPowerPort {
        attribute torque : Torque;
        attribute speed : RotationalSpeed;
        out item energy : RotationalMechanicalEnergy;
    }

    port def ThrustPort {
        attribute thrust : ThrustForce;
        out item flow : Airflow;
    }

    // ---- Requirements ----
    requirement def PropulsionPerformanceRequirement {
        doc << "The propulsion module shall produce forward thrust up to 5000 N.">>
        attribute maxThrust : ThrustForce = 5000 [N];
        subject prop : PropulsionModule;
        require prop.deliveredThrust <= maxThrust;
    }

    requirement def OperatingSpeedRequirement {
        doc << "The system shall operate continuously between 500 and 3000 RPM.">>
        attribute minSpeed : RotationalSpeed = 500 [rpm];
        attribute maxSpeed : RotationalSpeed = 3000 [rpm];
        subject prop : PropulsionModule;
        require prop.operatingSpeed >= minSpeed and prop.operatingSpeed <= maxSpeed;
    }

    requirement def PropellerDiameterRequirement {
        doc << "The propeller shall have a diameter of 2.4 m.">>
        attribute nominalDiameter : Diameter = 2.4 [m];
        subject prop : PropellerAssembly;
        require prop.diameter == nominalDiameter;
    }

    requirement def BladeStructuralIntegrityRequirement {
        doc << "Each blade shall withstand operational stress without failure at maximum rotational speed.">>
        attribute maxAllowableStress : BladeStress = 8.0e7 [Pa];
        subject blade : Blade;
        require blade.appliedStress <= maxAllowableStress;
    }

    requirement def EnergyConversionRequirement {
        doc << "The motor shall convert electrical energy into rotational mechanical energy.">>
        subject motor : ElectricMotor;
        require motor.conversionEfficiency >= 0.85;
    }

    // ---- Part definitions ----

    part def ElectricMotor {
        attribute ratedPower : ElectricalPower = 15000 [W];
        attribute maxTorque : Torque = 50 [N*m];
        attribute conversionEfficiency : Real = 0.90;

        port in electricalIn : ElectricalPowerPort;
        port in controlIn : ControlPort;
        port out mechanicalOut : MechanicalPowerPort;

        attribute commandedSpeed : RotationalSpeed;
        attribute actualSpeed : RotationalSpeed;
        attribute actualTorque : Torque;
        attribute deliveredPower : MechanicalPower;

        action def ConvertEnergy {
            in energy : ElectricalEnergy;
            in throttle : ControlCommand;
            out mechanical : RotationalMechanicalEnergy;
        }

        state motorStateMachine {
            entry; then Off;
            state Off;
            transition Off -> Starting
                when controlIn.throttle > 0.0;
            state Starting;
            transition Starting -> Running
                when actualSpeed >= 100 [rpm];
            state Running;
            transition Running -> Off
                when controlIn.throttle == 0.0;
        }

        compute {
            actualSpeed := controlIn.throttle * 3000 [rpm];
            actualTorque := electricalIn.voltage * electricalIn.current / max(actualSpeed, 1 [rpm]) * conversionEfficiency;
            deliveredPower := actualTorque * actualSpeed;
        }
    }

    part def DriveShaft {
        attribute length : Length = 0.5 [m];
        attribute maxTorque : Torque = 60 [N*m];
        attribute torsionalStiffness : Real = 5000 [N*m/rad];

        port in inputMech : MechanicalPowerPort;
        port out outputMech : MechanicalPowerPort;

        attribute transmittedTorque : Torque;
        attribute transmittedSpeed : RotationalSpeed;

        compute {
            transmittedTorque := inputMech.torque;
            transmittedSpeed := inputMech.speed;
        }
    }

    part def Blade {
        attribute bladeIndex : Integer;
        attribute length : Length = 1.1 [m];
        attribute chord : Length = 0.12 [m];
        attribute pitchAngle : Real = 15 [deg];
        attribute materialStrength : BladeStress = 1.0e8 [Pa];
        attribute appliedStress : BladeStress;

        compute {
            appliedStress := 6.5e7 [Pa];
        }
    }

    part def Hub {
        attribute hubDiameter : Diameter = 0.2 [m];
        attribute bladeCount : Integer = 4;
        part blades : Blade[4] = (
            for i in 1..4 {
                Blade { bladeIndex := i; }
            }
        );
    }

    part def PropellerAssembly {
        attribute diameter : Diameter = 2.4 [m];
        attribute bladeCount : Integer = 4;
        attribute maxThrust : ThrustForce = 5000 [N];

        port in mechInput : MechanicalPowerPort;
        port out thrustOut : ThrustPort;

        part hub : Hub;
        ref part blades : Blade[4] = hub.blades;

        attribute generatedThrust : ThrustForce;
        attribute airMassFlow : MassFlowRate;
        attribute exhaustAirSpeed : AirSpeed;

        compute {
            generatedThrust := mechInput.torque * mechInput.speed / 40 [m/s];
            airMassFlow := generatedThrust / 40 [m/s];
            exhaustAirSpeed := 40 [m/s];
        }
    }

    part def PropulsionModule {
        attribute operatingSpeed : RotationalSpeed;
        attribute deliveredThrust : ThrustForce;
        attribute nominalDiameter : Diameter = 2.4 [m];

        port in powerSupply : ElectricalPowerPort;
        port in commandInput : ControlPort;
        port out thrustOutput : ThrustPort;

        part motor : ElectricMotor {
            electricalIn := powerSupply;
            controlIn := commandInput;
        }

        part shaft : DriveShaft {
            inputMech := motor.mechanicalOut;
        }

        part propeller : PropellerAssembly {
            mechInput := shaft.outputMech;
            thrustOut := thrustOutput;
        }

        satisfy PropulsionPerformanceRequirement {
            subject prop := PropulsionModule::this;
        }
        satisfy OperatingSpeedRequirement {
            subject prop := PropulsionModule::this;
        }
        satisfy PropellerDiameterRequirement {
            subject prop := propeller;
        }
        satisfy BladeStructuralIntegrityRequirement {
            subject blade := propeller.hub.blades[1];
        }
        satisfy EnergyConversionRequirement {
            subject motor := motor;
        }

        compute {
            operatingSpeed := motor.actualSpeed;
            deliveredThrust := propeller.generatedThrust;
        }
    }

    // ---- Instantiated system ----
    part propulsionSystem : PropulsionModule {
        // External connections bound through ports at usage level
    }

    connection powerConnection connect propulsionSystem.powerSupply to propulsionSystem.motor.electricalIn;
    connection controlConnection connect propulsionSystem.commandInput to propulsionSystem.motor.controlIn;
    connection shaftConnection connect propulsionSystem.motor.mechanicalOut to propulsionSystem.shaft.inputMech;
    connection propDriveConnection connect propulsionSystem.shaft.outputMech to propulsionSystem.propeller.mechInput;
    connection thrustDelivery connect propulsionSystem.propeller.thrustOut to propulsionSystem.thrustOutput;
}
