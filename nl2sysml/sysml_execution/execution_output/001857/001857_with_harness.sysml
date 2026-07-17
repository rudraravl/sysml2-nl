package ScrollCompressorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def PressureValue :> ISQ::PressureValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def VolumeFlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def MassFlowRateValue :> ISQ::MassFlowRateValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def RotationalSpeedValue :> ISQ::AngularVelocityValue;
    attribute def TorqueValue :> ISQ::TorqueValue;
    attribute def VoltageValue :> ISQ::VoltageValue;
    attribute def CurrentValue :> ISQ::ElectricCurrentValue;

    item def Refrigerant {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute massFlowRate : MassFlowRateValue;
    }

    port def RefrigerantPort {
        attribute refrigerant : Refrigerant;
    }

    port def ElectricalPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    port def MechanicalPort {
        attribute torque : TorqueValue;
        attribute speed : RotationalSpeedValue;
    }

    part def ElectricMotor {
        attribute ratedPower : PowerValue;
        attribute efficiency : Real;
        port powerInput : ElectricalPort;
        port shaftOutput : MechanicalPort;

        assert constraint efficiencyRange {
            efficiency >= 0.80 and efficiency <= 0.95
        }
    }

    part def FixedScroll {
        attribute outerDiameter : Real;
        attribute scrollHeight : Real;
        attribute wallThickness : Real;
    }

    part def OrbitingScroll {
        attribute outerDiameter : Real;
        attribute scrollHeight : Real;
        attribute orbitRadius : Real;
        attribute wallThickness : Real;
    }

    part def CompressionChamber {
        attribute volume : Real;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    part def SuctionValve {
        attribute isOpen : Boolean;
        attribute flowArea : Real;
    }

    part def DischargeValve {
        attribute isOpen : Boolean;
        attribute flowArea : Real;
    }

    part def OilSeparator {
        attribute separationEfficiency : Real;
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;

        assert constraint {
            separationEfficiency >= 0.95
        }
    }

    part def ScrollCompressor {
        attribute compressionRatio : Real;
        attribute displacementVolume : Real;
        attribute operatingSpeed : RotationalSpeedValue;
        attribute isentropicEfficiency : Real;

        port suctionPort : RefrigerantPort;
        port dischargePort : RefrigerantPort;
        port electricalInput : ElectricalPort;

        part motor : ElectricMotor {
            attribute :>> ratedPower : PowerValue;
            attribute :>> efficiency = 0.88;
        }

        part fixedScroll : FixedScroll {
            attribute :>> outerDiameter = 0.15;
            attribute :>> scrollHeight = 0.06;
            attribute :>> wallThickness = 0.004;
        }

        part orbitingScroll : OrbitingScroll {
            attribute :>> outerDiameter = 0.15;
            attribute :>> scrollHeight = 0.06;
            attribute :>> orbitRadius = 0.006;
            attribute :>> wallThickness = 0.004;
        }

        part chambers : CompressionChamber[6];

        part suctionValve : SuctionValve {
            attribute :>> isOpen = true;
            attribute :>> flowArea = 0.0008;
        }

        part dischargeValve : DischargeValve {
            attribute :>> isOpen = false;
            attribute :>> flowArea = 0.0006;
        }

        assert constraint compressionRatioRange {
            compressionRatio >= 2.0 and compressionRatio <= 5.0
        }

        assert constraint efficiencyConstraint {
            isentropicEfficiency >= 0.65 and isentropicEfficiency <= 0.85
        }

        perform action compressRefrigerant {
            first start;
            then merge continuousCompression;

            action admitGas {
                doc /* Low-pressure refrigerant gas enters through suction port into outer compression chambers */
                in suctionPressure : PressureValue;
                in suctionTemp : TemperatureValue;
                out chambersFilled : Boolean;
            }
            then admitGas;

            action orbitScrollMotion {
                doc /* Orbiting scroll executes circular orbital motion driven by motor, creating moving compression pockets */
                in motorSpeed : RotationalSpeedValue;
                in orbitRadius : Real;
                out currentAngle : Real;
            }
            then orbitScrollMotion;

            action progressiveCompression {
                doc /* Gas pockets move radially inward with decreasing volume, increasing pressure and temperature */
                in initialVolume : Real;
                in initialPressure : PressureValue;
                in compressionRatio : Real;
                out finalPressure : PressureValue;
                out finalTemperature : TemperatureValue;
            }
            then progressiveCompression;

            action dischargeGas {
                doc /* Compressed high-pressure refrigerant exits through central discharge port */
                in dischargePressure : PressureValue;
                in dischargeTemp : TemperatureValue;
                out gasDischargedSuccessfully : Boolean;
            }
            then dischargeGas;

            then continuousCompression;
        }

        state machine CompressorStateMachine {
            initial state Stopped;
            state Starting;
            state Running;
            state Fault;

            transition first Stopped then Starting;
            transition Starting then Running;
            transition Running then Fault;
            transition Fault then Stopped;
            transition Running then Stopped;
        }
    }

    part def RefrigerationSystem {
        part compressor : ScrollCompressor {
            attribute :>> compressionRatio = 3.2;
            attribute :>> displacementVolume = 0.00018;
            attribute :>> operatingSpeed : RotationalSpeedValue;
            attribute :>> isentropicEfficiency = 0.72;

            part :>> motor {
                attribute :>> ratedPower : PowerValue;
            }
        }

        part oilSeparator : OilSeparator {
            attribute :>> separationEfficiency = 0.97;
        }

        port systemSuction : RefrigerantPort;
        port systemDischarge : RefrigerantPort;
        port powerSupply : ElectricalPort;
    }

    requirement <'REQ-SC-001'> primaryCompressionFunction {
        doc /* The scroll compressor system shall compress refrigerant gas from a low-pressure,
             * low-temperature state to a high-pressure, high-temperature state through continuous
             * orbital motion of scroll elements. The compression occurs as refrigerant is drawn into
             * outer crescent-shaped pockets formed between fixed and orbiting scrolls, then progressively
             * compressed as these pockets move radially inward toward the center with decreasing volume,
             * and finally discharged through a central port at elevated pressure and temperature.
             */
        subject system : RefrigerationSystem;

        assume constraint suctionConditions {
            doc /* Refrigerant enters at evaporator outlet conditions */
            system.systemSuction.refrigerant.pressure >= 300.0 and
            system.systemSuction.refrigerant.pressure <= 600.0 and
            system.systemSuction.refrigerant.temperature >= 273.0 and
            system.systemSuction.refrigerant.temperature <= 293.0
        }

        require constraint dischargeConditions {
            doc /* Refrigerant exits at condenser inlet conditions */
            system.systemDischarge.refrigerant.pressure >= 900.0 and
            system.systemDischarge.refrigerant.pressure <= 2000.0 and
            system.systemDischarge.refrigerant.temperature >= 323.0 and
            system.systemDischarge.refrigerant.temperature <= 363.0
        }

        require constraint compressionRatioAchieved {
            system.compressor.compressionRatio == 
                system.systemDischarge.refrigerant.pressure / system.systemSuction.refrigerant.pressure
        }
    }

    requirement <'REQ-SC-002'> performanceRequirement {
        doc /* The compressor shall achieve minimum volumetric and isentropic efficiency targets */
        subject compressor : ScrollCompressor;

        require constraint {
            compressor.isentropicEfficiency >= 0.65
        }
    }

    requirement <'REQ-SC-003'> operationalSafetyRequirement {
        doc /* The compressor shall operate within safe pressure and temperature limits */
        subject compressor : ScrollCompressor;

        require constraint pressureSafety {
            compressor.dischargePort.refrigerant.pressure <= 2500.0
        }

        require constraint temperatureSafety {
            compressor.dischargePort.refrigerant.temperature <= 393.0
        }
    }

    requirement <'REQ-SC-004'> reliabilityRequirement {
        doc /* The compressor shall maintain oil separation efficiency to ensure lubrication */
        subject system : RefrigerationSystem;

        require constraint {
            system.oilSeparator.separationEfficiency >= 0.95
        }
    }

    part refrigerationSystemInstance : RefrigerationSystem {
        port :>> systemSuction {
            attribute :>> refrigerant {
                attribute :>> pressure = 450.0;
                attribute :>> temperature = 283.0;
                attribute :>> massFlowRate = 0.025;
            }
        }

        port :>> systemDischarge {
            attribute :>> refrigerant {
                attribute :>> pressure = 1440.0;
                attribute :>> temperature = 343.0;
                attribute :>> massFlowRate = 0.025;
            }
        }

        port :>> powerSupply {
            attribute :>> voltage = 230.0;
            attribute :>> current = 10.5;
        }
    }

    satisfy primaryCompressionFunction by refrigerationSystemInstance;
    satisfy performanceRequirement by refrigerationSystemInstance.compressor;
    satisfy operationalSafetyRequirement by refrigerationSystemInstance.compressor;
    satisfy reliabilityRequirement by refrigerationSystemInstance;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import ScrollCompressorSystem::*;
    part testSubject : ElectricMotor;
    // TODO(human): define boundary input values for: pressure, temperature, massFlowRate, refrigerant, voltage, current, torque, speed
    // TODO(human): assert constraint assert_constraint_42 { testSubject.<attr> <= <limit> }
    // TODO(human): assert constraint assert_constraint_81 { testSubject.<attr> <= <limit> }
    // TODO(human): assert constraint assert_constraint_126 { testSubject.<attr> <= <limit> }
    // TODO(human): assert constraint assert_constraint_130 { testSubject.<attr> <= <limit> }
    // TODO(human): assert constraint dischargeConditions { testSubject.<attr> <= <limit> }
    // TODO(human): assert constraint compressionRatioAchieved { testSubject.<attr> <= <limit> }
    // TODO(human): assert constraint pressureSafety { testSubject.<attr> <= <limit> }
    // TODO(human): assert constraint temperatureSafety { testSubject.<attr> <= <limit> }
}
