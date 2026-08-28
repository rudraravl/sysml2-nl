package ScrollCompressorSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    attribute def PressureValue :> Real { doc "Refrigerant pressure in pascals" }
    attribute def TemperatureValue :> Real { doc "Refrigerant temperature in kelvin" }
    attribute def MassFlowRate :> Real { doc "Mass flow rate in kg/s" }
    attribute def VolumetricFlowRate :> Real { doc "Volumetric flow rate in m^3/s" }
    attribute def Power :> Real { doc "Electrical/mechanical power in watts" }
    attribute def RotationalSpeed :> Real { doc "Rotational speed in rad/s" }
    attribute def Efficiency :> Real { doc "Dimensionless efficiency ratio" }
    attribute def OilFraction :> Real { doc "Mass fraction of oil in refrigerant" }
    attribute def Volume :> Real { doc "Pocket volume in m^3" }

    // ---- Item types ----
    item def RefrigerantGas {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute massFlow : MassFlowRate;
    }

    item def OilMist {
        attribute concentration : OilFraction;
        attribute massFlow : MassFlowRate;
    }

    item def LubricatingOil {
        attribute temperature : TemperatureValue;
        attribute massFlow : MassFlowRate;
    }

    item def CompressedMixture {
        attribute refrigerant : RefrigerantGas;
        attribute oil : OilMist;
    }

    // ---- Port definitions ----
    port def SuctionPort {
        out item suctionGas : RefrigerantGas;
    }

    port def DischargePort {
        in item compressedGas : RefrigerantGas;
    }

    port def MixturePort {
        out item mixture : CompressedMixture;
    }

    port def CleanGasPort {
        out item cleanGas : RefrigerantGas;
    }

    port def OilReturnPort {
        out item returnOil : LubricatingOil;
    }

    port def ElectricalPowerPort {
        in item power : Power;
    }

    port def MechanicalDrivePort {
        out item torque : Power;
        out item speed : RotationalSpeed;
    }

    // ---- Requirements ----
    requirement def CompressionPerformanceRequirement {
        doc "The compressor shall raise refrigerant pressure from suction to discharge level."
        attribute suctionPressure : PressureValue = 300000;
        attribute dischargePressure : PressureValue = 2500000;
        attribute suctionTemperature : TemperatureValue = 280.0;
        attribute dischargeTemperature : TemperatureValue = 380.0;
        require { dischargePressure > suctionPressure }
        require { dischargeTemperature > suctionTemperature }
    }

    requirement def EfficiencyRequirement {
        doc "The compressor shall achieve at least the specified isentropic efficiency."
        attribute minIsentropicEfficiency : Efficiency = 0.70;
        require { actualEfficiency >= minIsentropicEfficiency }
        attribute actualEfficiency : Efficiency;
    }

    requirement def SafetyLimitsRequirement {
        doc "The compressor shall operate within safe pressure and temperature limits."
        attribute maxDischargePressure : PressureValue = 3000000;
        attribute maxDischargeTemperature : TemperatureValue = 420.0;
        attribute maxOilTemperature : TemperatureValue = 400.0;
        require { dischargePressure <= maxDischargePressure }
        require { dischargeTemperature <= maxDischargeTemperature }
    }

    requirement def OilSeparationRequirement {
        doc "The oil separator shall remove lubricating oil from the refrigerant stream."
        attribute maxOilFractionDownstream : OilFraction = 0.005;
        require { downstreamOilFraction <= maxOilFractionDownstream }
        attribute downstreamOilFraction : OilFraction;
    }

    requirement def OperationalStateRequirement {
        doc "The system shall transition through defined operational states."
        attribute validStates : String = "stopped, starting, running, fault";
        require { currentState in validStates }
    }

    // ---- Parts ----

    part def FixedScroll {
        doc "Stationary spiral component of the scroll compressor.";
        attribute spiralPitch : Real = 0.004;
        attribute spiralHeight : Real = 0.030;
        attribute involuteRadius : Real = 0.060;
        port def CenterDischarge {
            out item dischargedGas : RefrigerantGas;
        }
        port discharge : CenterDischarge;
    }

    part def OrbitingScroll {
        doc "Moving spiral component that orbits relative to the fixed scroll.";
        attribute spiralPitch : Real = 0.004;
        attribute spiralHeight : Real = 0.030;
        attribute orbitRadius : Real = 0.004;
        attribute currentAngle : Real;
        port driveInput : MechanicalDrivePort;
    }

    part def CompressionChamber {
        doc "Represents the crescent-shaped gas pockets between scrolls.";
        attribute pocketVolume : Volume;
        attribute pocketPressure : PressureValue;
        attribute pocketTemperature : TemperatureValue;
        attribute compressionRatio : Real;
        
        action def CompressPocket {
            in initialVolume : Volume;
            in initialPressure : PressureValue;
            out finalVolume : Volume;
            out finalPressure : PressureValue;
            out finalTemperature : TemperatureValue;
        }
    }

    part def ElectricMotor {
        doc "Integrated high-efficiency electric motor driving the orbiting scroll.";
        attribute ratedPower : Power = 3000.0;
        attribute ratedSpeed : RotationalSpeed = 314.0;
        attribute efficiency : Efficiency = 0.92;
        attribute inputPower : Power;
        attribute outputTorque : Power;
        attribute outputSpeed : RotationalSpeed;
        port powerInput : ElectricalPowerPort;
        port driveOutput : MechanicalDrivePort;
        
        action def GenerateTorque {
            in electricalPower : Power;
            out mechanicalTorque : Power;
            out rotationalSpeed : RotationalSpeed;
        }
    }

    part def ScrollCompressor {
        doc "Core scroll compressor assembly.";
        attribute suctionPressure : PressureValue;
        attribute dischargePressure : PressureValue;
        attribute suctionTemperature : TemperatureValue;
        attribute dischargeTemperature : TemperatureValue;
        attribute massFlowRate : MassFlowRate;
        attribute isentropicEfficiency : Efficiency;
        
        port suction : SuctionPort;
        port discharge : DischargePort;
        port powerIn : ElectricalPowerPort;
        
        part fixedScroll : FixedScroll;
        part orbitingScroll : OrbitingScroll;
        part motor : ElectricMotor;
        part chamber : CompressionChamber;
        
        connection motorDrive from motor.driveOutput to orbitingScroll.driveInput;
        
        action def CompressionCycle {
            doc "Continuous compression process action.";
            in suctionGas : RefrigerantGas;
            out compressedGas : RefrigerantGas;
            
            action DrawInGas {
                in gas : RefrigerantGas;
                out trappedGas : RefrigerantGas;
            }
            action SealPocket {
                in gas : RefrigerantGas;
                out sealedGas : RefrigerantGas;
            }
            action ReduceVolume {
                in gas : RefrigerantGas;
                out pressurizedGas : RefrigerantGas;
            }
            action DischargeGas {
                in gas : RefrigerantGas;
                out expelledGas : RefrigerantGas;
            }
            
            flow from DrawInGas.trappedGas to SealPocket.gas;
            flow from SealPocket.sealedGas to ReduceVolume.gas;
            flow from ReduceVolume.pressurizedGas to DischargeGas.gas;
        }
    }

    part def OilSeparator {
        doc "Removes lubricating oil from hot high-pressure refrigerant gas.";
        attribute inletOilFraction : OilFraction;
        attribute outletOilFraction : OilFraction;
        attribute separationEfficiency : Efficiency = 0.98;
        attribute operatingPressure : PressureValue;
        attribute operatingTemperature : TemperatureValue;
        
        port mixtureIn : MixturePort;
        port cleanGasOut : CleanGasPort;
        port oilReturn : OilReturnPort;
        
        action def SeparateOil {
            in mixture : CompressedMixture;
            out cleanRefrigerant : RefrigerantGas;
            out recoveredOil : LubricatingOil;
        }
    }

    part def RefrigerationSystem {
        doc "Complete scroll compressor refrigeration system.";
        
        attribute currentState : String;
        attribute systemEfficiency : Efficiency;
        attribute totalMassFlow : MassFlowRate;
        
        port systemSuction : SuctionPort;
        port systemDischarge : CleanGasPort;
        port systemPower : ElectricalPowerPort;
        port systemOilReturn : OilReturnPort;
        
        part compressor : ScrollCompressor;
        part oilSeparator : OilSeparator;
        
        // Requirements satisfaction
        satisfy CompressionPerformanceRequirement {
            attribute suctionPressure = compressor.suctionPressure;
            attribute dischargePressure = compressor.dischargePressure;
            attribute suctionTemperature = compressor.suctionTemperature;
            attribute dischargeTemperature = compressor.dischargeTemperature;
        }
        satisfy EfficiencyRequirement {
            attribute actualEfficiency = compressor.isentropicEfficiency;
        }
        satisfy SafetyLimitsRequirement {
            attribute dischargePressure = compressor.dischargePressure;
            attribute dischargeTemperature = compressor.dischargeTemperature;
            attribute maxOilTemperature = oilSeparator.operatingTemperature;
        }
        satisfy OilSeparationRequirement {
            attribute downstreamOilFraction = oilSeparator.outletOilFraction;
        }
        satisfy OperationalStateRequirement {
            attribute currentState = currentState;
        }
        
        // Connections
        connection powerFeed from systemPower to compressor.powerIn;
        connection suctionFeed from systemSuction to compressor.suction;
        connection dischargeToSeparator from compressor.discharge to oilSeparator.mixtureIn {
            doc "Hot compressed gas with oil mist flows to separator.";
        }
        connection cleanGasOut from oilSeparator.cleanGasOut to systemDischarge;
        connection oilReturnLine from oilSeparator.oilReturn to systemOilReturn;
        
        // State machine
        state def OperationalStates {
            doc "Operational state machine for the refrigeration system.";
            
            initial state Stopped {
                entry action { currentState = "stopped"; }
                doc "System is off, no compression occurs.";
            }
            
            state Starting {
                entry action { currentState = "starting"; }
                doc "Motor ramping up, scrolls beginning to engage.";
                do action {
                    compressor.motor.inputPower = 0.0;
                    compressor.motor.inputPower = compressor.motor.ratedPower * 0.5;
                }
            }
            
            state Running {
                entry action { currentState = "running"; }
                doc "Continuous compression at steady state.";
                do action {
                    compressor.motor.inputPower = compressor.motor.ratedPower;
                    compressor.massFlowRate = 0.05;
                    compressor.suctionPressure = 300000.0;
                    compressor.dischargePressure = 2500000.0;
                    compressor.suctionTemperature = 280.0;
                    compressor.dischargeTemperature = 380.0;
                    compressor.isentropicEfficiency = 0.72;
                    oilSeparator.inletOilFraction = 0.03;
                    oilSeparator.outletOilFraction = oilSeparator.inletOilFraction * (1.0 - oilSeparator.separationEfficiency);
                    oilSeparator.operatingPressure = compressor.dischargePressure;
                    oilSeparator.operatingTemperature = compressor.dischargeTemperature;
                }
            }
            
            state Fault {
                entry action { currentState = "fault"; }
                doc "Operational issue detected, system shut down for safety.";
                do action {
                    compressor.motor.inputPower = 0.0;
                    compressor.massFlowRate = 0.0;
                }
            }
            
            transition Stopped_to_Starting
                from Stopped to Starting
                when compressor.motor.inputPower > 0.0;
            
            transition Starting_to_Running
                from Starting to Running
                when compressor.motor.outputSpeed >= compressor.motor.ratedSpeed * 0.95;
            
            transition Running_to_Fault
                from Running to Fault
                when compressor.dischargePressure > 3000000.0
                    or compressor.dischargeTemperature > 420.0;
            
            transition Starting_to_Fault
                from Starting to Fault
                when compressor.dischargePressure > 3000000.0;
            
            transition Fault_to_Stopped
                from Fault to Stopped
                when compressor.motor.inputPower == 0.0;
            
            transition Running_to_Stopped
                from Running to Stopped
                when compressor.motor.inputPower == 0.0;
        }
        
        stateMachine : OperationalStates;
    }
}
