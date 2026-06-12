package GasCompressorSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    value def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    value def MassFlowRate :> ISQ::massFlowRate {
        unit = SI::kilogram / SI::second;
    }

    value def RotationalSpeed :> ISQ::angularVelocity {
        unit = SI::radian / SI::second;
    }

    value def Power :> ISQ::power {
        unit = SI::watt;
    }

    value def Efficiency :> ScalarValues::Real {
        unit = SI::one;
    }

    value def VibrationLevel :> ISQ::acceleration {
        unit = SI::meter / SI::second^2;
    }

    value def TimeDuration :> ISQ::duration {
        unit = SI::second;
    }

    item def Gas {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute massFlowRate : MassFlowRate;
        attribute composition : String;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute frequency : Real;
        attribute activePower : Power;
    }

    item def MechanicalTorque {
        attribute shaftSpeed : RotationalSpeed;
        attribute transmittedPower : Power;
    }

    item def CoolingMedium {
        attribute inletTemperature : Temperature;
        attribute outletTemperature : Temperature;
        attribute massFlowRate : MassFlowRate;
    }

    port def GasInletPort {
        in item incomingGas : Gas;
    }

    port def GasOutletPort {
        out item compressedGas : Gas;
    }

    port def ElectricalPowerPort {
        in item suppliedPower : ElectricalPower;
    }

    port def MechanicalDrivePort {
        out item driveTorque : MechanicalTorque;
    }

    port def CoolingPort {
        in item coolantIn : CoolingMedium;
        out item coolantOut : CoolingMedium;
    }

    port def ControlPort {
        in item startCommand : Boolean;
        in item stopCommand : Boolean;
        in item emergencyStop : Boolean;
        in item targetDischargePressure : Pressure;
        out item runningStatus : Boolean;
        out item faultStatus : Boolean;
    }

    part def ElectricMotor {
        port powerInput : ElectricalPowerPort;
        port shaftOutput : MechanicalDrivePort;

        attribute ratedPower : Power = 750000 [SI::watt];
        attribute ratedSpeed : RotationalSpeed = 377 [SI::radian / SI::second];
        attribute motorEfficiency : Efficiency = 0.94;

        action convertElectricalToMechanicalPower {
            in item electricalInput : ElectricalPower;
            out item mechanicalOutput : MechanicalTorque;
        }
    }

    part def CompressorStage {
        port gasIn : GasInletPort;
        port gasOut : GasOutletPort;
        port shaftInput : MechanicalDrivePort;

        attribute pressureRatio : Real = 3.5;
        attribute stageEfficiency : Efficiency = 0.78;
        attribute designMassFlowRate : MassFlowRate = 2.4 [SI::kilogram / SI::second];
        attribute maxDischargeTemperature : Temperature = 455 [SI::kelvin];

        action compressGas {
            in item lowPressureGas : Gas;
            in item driveTorque : MechanicalTorque;
            out item highPressureGas : Gas;
        }
    }

    part def Intercooler {
        port hotGasIn : GasInletPort;
        port cooledGasOut : GasOutletPort;
        port coolingInterface : CoolingPort;

        attribute coolingCapacity : Power = 180000 [SI::watt];
        attribute targetOutletTemperature : Temperature = 315 [SI::kelvin];
        attribute pressureDrop : Pressure = 12000 [SI::pascal];

        action removeHeat {
            in item hotGas : Gas;
            in item coolant : CoolingMedium;
            out item cooledGas : Gas;
        }
    }

    part def LubricationSystem {
        attribute oilPressure : Pressure = 350000 [SI::pascal];
        attribute oilTemperature : Temperature = 330 [SI::kelvin];
        attribute minimumOilPressure : Pressure = 200000 [SI::pascal];

        action circulateLubricant;
        action detectLowOilPressure;
    }

    part def SealSystem {
        attribute sealGasPressure : Pressure = 650000 [SI::pascal];
        attribute maximumLeakageRate : MassFlowRate = 0.005 [SI::kilogram / SI::second];

        action maintainShaftSeal;
        action detectSealLeakage;
    }

    part def ControlSystem {
        port controls : ControlPort;

        attribute commandedPressure : Pressure = 1200000 [SI::pascal];
        attribute measuredDischargePressure : Pressure;
        attribute measuredDischargeTemperature : Temperature;
        attribute measuredVibration : VibrationLevel;
        attribute shutdownDelay : TimeDuration = 2 [SI::second];

        action regulateCapacity {
            in item targetPressure : Pressure;
            in item actualPressure : Pressure;
            out item motorSpeedCommand : RotationalSpeed;
        }

        action evaluateProtection {
            in item dischargeTemperature : Temperature;
            in item vibration : VibrationLevel;
            in item oilPressure : Pressure;
            out item tripRequired : Boolean;
        }

        state def CompressorOperatingState {
            state off;
            state starting;
            state running;
            state unloading;
            state stopping;
            state tripped;

            transition first off;

            transition startSystem
                first off
                accept startCommand
                then starting;

            transition reachStableSpeed
                first starting
                if measuredDischargePressure < commandedPressure
                then running;

            transition unloadAtHighPressure
                first running
                if measuredDischargePressure >= commandedPressure
                then unloading;

            transition reloadAtLowPressure
                first unloading
                if measuredDischargePressure < commandedPressure * 0.95
                then running;

            transition normalStop
                first running
                accept stopCommand
                then stopping;

            transition stopped
                first stopping
                then off;

            transition emergencyTripFromStarting
                first starting
                accept emergencyStop
                then tripped;

            transition emergencyTripFromRunning
                first running
                accept emergencyStop
                then tripped;

            transition protectionTrip
                first running
                if measuredDischargeTemperature > 455 [SI::kelvin] or measuredVibration > 20 [SI::meter / SI::second^2]
                then tripped;
        }
    }

    part def GasCompressor {
        port suctionPort : GasInletPort;
        port dischargePort : GasOutletPort;
        port electricalSupply : ElectricalPowerPort;
        port coolingWater : CoolingPort;
        port commandInterface : ControlPort;

        part motor : ElectricMotor;
        part firstStage : CompressorStage {
            attribute pressureRatio = 2.8;
        }
        part intercooler : Intercooler;
        part secondStage : CompressorStage {
            attribute pressureRatio = 2.5;
        }
        part lubrication : LubricationSystem;
        part seals : SealSystem;
        part controller : ControlSystem;

        attribute nominalSuctionPressure : Pressure = 101325 [SI::pascal];
        attribute nominalDischargePressure : Pressure = 1200000 [SI::pascal];
        attribute nominalSuctionTemperature : Temperature = 293 [SI::kelvin];
        attribute nominalDischargeTemperature : Temperature = 410 [SI::kelvin];
        attribute nominalMassFlowRate : MassFlowRate = 2.4 [SI::kilogram / SI::second];
        attribute overallEfficiency : Efficiency = 0.72;
        attribute maximumVibration : VibrationLevel = 20 [SI::meter / SI::second^2];

        connect electricalSupply to motor.powerInput;
        connect motor.shaftOutput to firstStage.shaftInput;
        connect motor.shaftOutput to secondStage.shaftInput;
        connect suctionPort to firstStage.gasIn;
        connect firstStage.gasOut to intercooler.hotGasIn;
        connect intercooler.cooledGasOut to secondStage.gasIn;
        connect secondStage.gasOut to dischargePort;
        connect coolingWater to intercooler.coolingInterface;
        connect commandInterface to controller.controls;

        action performPrimaryFunction {
            in item suctionGas : Gas;
            in item electricalEnergy : ElectricalPower;
            out item pressurizedGas : Gas;

            objective {
                pressurizedGas.pressure > suctionGas.pressure;
                pressurizedGas.massFlowRate == suctionGas.massFlowRate;
                pressurizedGas.pressure >= nominalDischargePressure;
            }
        }

        action startCompressor {
            first startLubrication : lubrication.circulateLubricant;
            then energizeMotor : motor.convertElectricalToMechanicalPower;
            then establishFlow : firstStage.compressGas;
        }

        action shutdownCompressor {
            first unloadCompressor : controller.regulateCapacity;
            then stopMotor;
            then continueLubricationCooldown : lubrication.circulateLubricant;
        }

        action protectCompressor {
            first monitorLimits : controller.evaluateProtection;
            then isolateOnTrip;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject compressor : GasCompressor;

        require constraint {
            compressor.dischargePort.compressedGas.pressure > compressor.suctionPort.incomingGas.pressure
        }

        doc /* The gas compressor shall increase the pressure of an incoming gas stream and deliver it as a controlled, higher-pressure gas stream suitable for downstream process use. */
    }

    requirement def FlowContinuityRequirement {
        subject compressor : GasCompressor;

        require constraint {
            compressor.dischargePort.compressedGas.massFlowRate >= 0.98 * compressor.suctionPort.incomingGas.massFlowRate
        }

        doc /* The compressor shall preserve gas flow continuity during normal operation with no more than two percent process loss. */
    }

    requirement def DischargePressureRequirement {
        subject compressor : GasCompressor;

        require constraint {
            compressor.dischargePort.compressedGas.pressure >= 1200000 [SI::pascal]
        }

        doc /* The compressor shall provide a nominal discharge pressure of at least 1.2 MPa during rated operation. */
    }

    requirement def ThermalProtectionRequirement {
        subject compressor : GasCompressor;

        require constraint {
            compressor.dischargePort.compressedGas.temperature <= 455 [SI::kelvin]
        }

        doc /* The compressor shall limit discharge gas temperature to protect downstream equipment and compressor internals. */
    }

    requirement def VibrationProtectionRequirement {
        subject compressor : GasCompressor;

        require constraint {
            compressor.maximumVibration <= 20 [SI::meter / SI::second^2]
        }

        doc /* The compressor shall trip or alarm before vibration exceeds the defined safe operating limit. */
    }

    requirement def ControlRequirement {
        subject compressor : GasCompressor;

        require constraint {
            compressor.commandInterface.runningStatus == true implies compressor.dischargePort.compressedGas.pressure >= compressor.controller.commandedPressure * 0.95
        }

        doc /* The control system shall regulate compressor operation to maintain discharge pressure near the commanded pressure setpoint. */
    }

    part gasCompressionSystem : GasCompressor;

    satisfy PrimaryFunctionRequirement by gasCompressionSystem;
    satisfy FlowContinuityRequirement by gasCompressionSystem;
    satisfy DischargePressureRequirement by gasCompressionSystem;
    satisfy ThermalProtectionRequirement by gasCompressionSystem;
    satisfy VibrationProtectionRequirement by gasCompressionSystem;
    satisfy ControlRequirement by gasCompressionSystem;
}