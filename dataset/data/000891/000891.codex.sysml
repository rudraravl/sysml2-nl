package HighDensitySolidsPumpingSubsystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = SI::cubicMetrePerSecond;
    }

    attribute def Density :> ISQ::massDensity {
        unit = SI::kilogramPerCubicMetre;
    }

    attribute def DynamicViscosity :> ISQ::dynamicViscosity {
        unit = SI::pascalSecond;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def RotationalSpeed :> ISQ::angularVelocity {
        unit = SI::radianPerSecond;
    }

    attribute def Volume :> ISQ::volume {
        unit = SI::cubicMetre;
    }

    attribute def MassFraction :> ScalarValues::Real {
        range = "0..1";
    }

    attribute def Percent :> ScalarValues::Real {
        range = "0..100";
    }

    attribute def Torque :> ISQ::torque {
        unit = SI::newtonMetre;
    }

    item def HighDensitySlurry {
        attribute solidsMassFraction : MassFraction;
        attribute bulkDensity : Density;
        attribute apparentViscosity : DynamicViscosity;
        attribute temperature : Temperature;
        attribute particleDiameterD95 : ISQ::length {
            unit = SI::metre;
        }
        attribute abrasivenessIndex : ScalarValues::Real;
    }

    item def CleanWater {
        attribute temperature : Temperature;
        attribute density : Density;
    }

    item def HydraulicOil {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute cleanlinessCode : ScalarValues::String;
    }

    item def ElectricalPower {
        attribute voltage : ISQ::electricPotential {
            unit = SI::volt;
        }
        attribute current : ISQ::electricCurrent {
            unit = SI::ampere;
        }
        attribute frequency : ISQ::frequency {
            unit = SI::hertz;
        }
        attribute availablePower : Power;
    }

    item def ControlSignal {
        attribute commandValue : Percent;
        attribute valid : Boolean;
    }

    item def SensorSignal {
        attribute measuredValue : ScalarValues::Real;
        attribute valid : Boolean;
        attribute timestamp : ScalarValues::Real;
    }

    port def SlurryInletPort {
        in item slurry : HighDensitySlurry;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def SlurryOutletPort {
        out item slurry : HighDensitySlurry;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def WaterPort {
        in item water : CleanWater;
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }

    port def HydraulicSupplyPort {
        in item oil : HydraulicOil;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def HydraulicReturnPort {
        out item oil : HydraulicOil;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def ElectricalPowerPort {
        in item powerFeed : ElectricalPower;
    }

    port def CommandPort {
        in item command : ControlSignal;
    }

    port def TelemetryPort {
        out item telemetry : SensorSignal;
    }

    part def HighDensitySolidsPump {
        attribute ratedDischargePressure : Pressure = 15000000 [SI::pascal];
        attribute ratedFlowRate : FlowRate = 0.075 [SI::cubicMetrePerSecond];
        attribute minimumFlowRate : FlowRate = 0.008 [SI::cubicMetrePerSecond];
        attribute maximumSolidsMassFraction : MassFraction = 0.72;
        attribute maximumParticleDiameterD95 : ISQ::length = 0.012 [SI::metre];
        attribute volumetricEfficiency : Percent = 88;
        attribute strokeRate : RotationalSpeed = 1.57 [SI::radianPerSecond];
        attribute chamberVolume : Volume = 0.038 [SI::cubicMetre];

        port suction : SlurryInletPort;
        port discharge : SlurryOutletPort;
        port hydraulicSupply : HydraulicSupplyPort;
        port hydraulicReturn : HydraulicReturnPort;
        port speedCommand : CommandPort;
        port statusTelemetry : TelemetryPort;

        part leftPumpingChamber {
            attribute fillVolume : Volume = 0.038 [SI::cubicMetre];
            attribute chamberPressure : Pressure = 101325 [SI::pascal];
        }

        part rightPumpingChamber {
            attribute fillVolume : Volume = 0.038 [SI::cubicMetre];
            attribute chamberPressure : Pressure = 101325 [SI::pascal];
        }

        part suctionCheckValve {
            attribute crackingPressure : Pressure = 25000 [SI::pascal];
            attribute openFraction : Percent = 0;
        }

        part dischargeCheckValve {
            attribute crackingPressure : Pressure = 60000 [SI::pascal];
            attribute openFraction : Percent = 0;
        }

        perform action pumpSlurry {
            in item incomingSlurry : HighDensitySlurry;
            in attribute commandedStrokeRate : RotationalSpeed;
            out item pressurizedSlurry : HighDensitySlurry;
            out attribute deliveredFlowRate : FlowRate;
            out attribute deliveredPressure : Pressure;

            first startStroke;
            then fillChamber;
            then compressCharge;
            then dischargeCharge;
            then swapChambers;

            action startStroke;
            action fillChamber;
            action compressCharge;
            action dischargeCharge;
            action swapChambers;
        }

        state machine pumpOperatingMode {
            state Off;
            state Standby;
            state Priming;
            state Running;
            state Flushing;
            state Faulted;

            entry; then Off;

            transition Off_to_Standby
                first Off
                accept startCommand
                if speedCommand.command.valid
                then Standby;

            transition Standby_to_Priming
                first Standby
                accept primeCommand
                then Priming;

            transition Priming_to_Running
                first Priming
                accept suctionFilled
                if suction.flowRate >= minimumFlowRate
                then Running;

            transition Running_to_Flushing
                first Running
                accept flushCommand
                then Flushing;

            transition Running_to_Faulted
                first Running
                accept faultDetected
                if discharge.pressure > ratedDischargePressure
                then Faulted;

            transition Flushing_to_Standby
                first Flushing
                accept flushComplete
                then Standby;

            transition Standby_to_Off
                first Standby
                accept stopCommand
                then Off;

            transition Faulted_to_Standby
                first Faulted
                accept resetCommand
                if discharge.pressure < 500000 [SI::pascal]
                then Standby;
        }
    }

    part def HydraulicPowerUnit {
        attribute motorRatedPower : Power = 315000 [SI::watt];
        attribute systemPressure : Pressure = 21000000 [SI::pascal];
        attribute reservoirVolume : Volume = 1.25 [SI::cubicMetre];
        attribute oilTemperature : Temperature = 318 [SI::kelvin];

        port electricalInput : ElectricalPowerPort;
        port hydraulicOutput : HydraulicSupplyPort;
        port hydraulicReturn : HydraulicReturnPort;
        port commandInput : CommandPort;
        port telemetryOutput : TelemetryPort;

        part electricMotor {
            attribute ratedPower : Power = 315000 [SI::watt];
            attribute ratedSpeed : RotationalSpeed = 188.5 [SI::radianPerSecond];
            attribute ratedTorque : Torque = 1671 [SI::newtonMetre];
        }

        part variableDisplacementPump {
            attribute displacement : Volume = 0.00021 [SI::cubicMetre];
            attribute outletPressure : Pressure = 21000000 [SI::pascal];
            attribute efficiency : Percent = 91;
        }

        part oilCooler {
            attribute heatRejectionPower : Power = 42000 [SI::watt];
            attribute outletTemperatureSetpoint : Temperature = 313 [SI::kelvin];
        }

        part returnFilter {
            attribute filtrationRating : ISQ::length = 0.000010 [SI::metre];
            attribute differentialPressureLimit : Pressure = 250000 [SI::pascal];
        }

        state machine hydraulicUnitMode {
            state Deenergized;
            state Starting;
            state PressureReady;
            state CoolingLimited;
            state Shutdown;

            entry; then Deenergized;

            transition Deenergized_to_Starting
                first Deenergized
                accept enableHydraulics
                then Starting;

            transition Starting_to_PressureReady
                first Starting
                accept pressureReached
                if systemPressure >= 18000000 [SI::pascal]
                then PressureReady;

            transition PressureReady_to_CoolingLimited
                first PressureReady
                accept highOilTemperature
                if oilTemperature > 333 [SI::kelvin]
                then CoolingLimited;

            transition CoolingLimited_to_PressureReady
                first CoolingLimited
                accept oilTemperatureNormal
                if oilTemperature < 323 [SI::kelvin]
                then PressureReady;

            transition PressureReady_to_Shutdown
                first PressureReady
                accept disableHydraulics
                then Shutdown;

            transition Shutdown_to_Deenergized
                first Shutdown
                accept stopped
                then Deenergized;
        }
    }

    part def FeedHopper {
        attribute workingVolume : Volume = 6.0 [SI::cubicMetre];
        attribute lowLevelThreshold : Percent = 15;
        attribute highLevelThreshold : Percent = 92;
        attribute currentLevel : Percent = 60;

        port outlet : SlurryOutletPort;
        port levelTelemetry : TelemetryPort;

        part agitationSystem {
            attribute motorPower : Power = 22000 [SI::watt];
            attribute agitatorSpeed : RotationalSpeed = 3.14 [SI::radianPerSecond];
        }

        perform action conditionSlurry {
            in item rawSlurry : HighDensitySlurry;
            out item homogenizedSlurry : HighDensitySlurry;
        }
    }

    part def DischargePipeline {
        attribute internalDiameter : ISQ::length = 0.18 [SI::metre];
        attribute length : ISQ::length = 85 [SI::metre];
        attribute designPressure : Pressure = 16000000 [SI::pascal];
        attribute pressureDropAtRatedFlow : Pressure = 1800000 [SI::pascal];

        port inlet : SlurryInletPort;
        port outlet : SlurryOutletPort;

        part pressureReliefValve {
            attribute setPressure : Pressure = 14500000 [SI::pascal];
            attribute reseatPressure : Pressure = 13000000 [SI::pascal];
        }

        part pulsationDampener {
            attribute gasPrechargePressure : Pressure = 6000000 [SI::pascal];
            attribute shellVolume : Volume = 0.5 [SI::cubicMetre];
        }
    }

    part def FlushWaterSystem {
        attribute tankVolume : Volume = 2.5 [SI::cubicMetre];
        attribute flushFlowRate : FlowRate = 0.025 [SI::cubicMetrePerSecond];
        attribute flushPressure : Pressure = 700000 [SI::pascal];

        port waterOutput : WaterPort;
        port commandInput : CommandPort;

        perform action flushPumpAndLine {
            out item flushingWater : CleanWater;
            out attribute flushDuration : ScalarValues::Real;
        }
    }

    part def InstrumentationAndControl {
        port pumpCommand : CommandPort;
        port hydraulicCommand : CommandPort;
        port flushCommand : CommandPort;
        port pumpTelemetry : TelemetryPort;
        port hydraulicTelemetry : TelemetryPort;
        port hopperTelemetry : TelemetryPort;
        port supervisoryTelemetry : TelemetryPort;

        attribute commandedFlowRate : FlowRate = 0.055 [SI::cubicMetrePerSecond];
        attribute highDischargePressureTrip : Pressure = 15000000 [SI::pascal];
        attribute lowSuctionPressureTrip : Pressure = 50000 [SI::pascal];
        attribute minimumHopperLevelPermissive : Percent = 12;

        perform action regulatePumpFlow {
            in attribute flowSetpoint : FlowRate;
            in attribute measuredFlow : FlowRate;
            out item speedDemand : ControlSignal;
        }

        perform action protectSubsystem {
            in attribute dischargePressure : Pressure;
            in attribute suctionPressure : Pressure;
            in attribute hopperLevel : Percent;
            out item tripCommand : ControlSignal;
        }

        state machine controlMode {
            state LocalStopped;
            state LocalManual;
            state RemoteAutomatic;
            state EmergencyStop;

            entry; then LocalStopped;

            transition LocalStopped_to_RemoteAutomatic
                first LocalStopped
                accept remoteStart
                then RemoteAutomatic;

            transition RemoteAutomatic_to_LocalManual
                first RemoteAutomatic
                accept localTakeover
                then LocalManual;

            transition LocalManual_to_LocalStopped
                first LocalManual
                accept stop
                then LocalStopped;

            transition RemoteAutomatic_to_EmergencyStop
                first RemoteAutomatic
                accept emergencyStop
                then EmergencyStop;

            transition LocalManual_to_EmergencyStop
                first LocalManual
                accept emergencyStop
                then EmergencyStop;

            transition EmergencyStop_to_LocalStopped
                first EmergencyStop
                accept reset
                then LocalStopped;
        }
    }

    part def HighDensitySolidsPumpingSubsystem {
        attribute requiredFlowRate : FlowRate = 0.05 [SI::cubicMetrePerSecond];
        attribute requiredDischargePressure : Pressure = 12000000 [SI::pascal];
        attribute maximumAllowedSolidsMassFraction : MassFraction = 0.70;
        attribute minimumAvailability : Percent = 96;
        attribute designLife : ISQ::time = 20 [SI::year];

        port slurryFeed : SlurryInletPort;
        port slurryDelivery : SlurryOutletPort;
        port electricalSupply : ElectricalPowerPort;
        port serviceWaterSupply : WaterPort;
        port remoteCommand : CommandPort;
        port remoteTelemetry : TelemetryPort;

        part feedHopper : FeedHopper;
        part highDensitySolidsPump : HighDensitySolidsPump;
        part hydraulicPowerUnit : HydraulicPowerUnit;
        part dischargePipeline : DischargePipeline;
        part flushWaterSystem : FlushWaterSystem;
        part controlSystem : InstrumentationAndControl;

        connect slurryFeed to feedHopper.outlet;
        connect feedHopper.outlet to highDensitySolidsPump.suction;
        connect highDensitySolidsPump.discharge to dischargePipeline.inlet;
        connect dischargePipeline.outlet to slurryDelivery;

        connect electricalSupply to hydraulicPowerUnit.electricalInput;
        connect hydraulicPowerUnit.hydraulicOutput to highDensitySolidsPump.hydraulicSupply;
        connect highDensitySolidsPump.hydraulicReturn to hydraulicPowerUnit.hydraulicReturn;

        connect serviceWaterSupply to flushWaterSystem.waterOutput;
        connect flushWaterSystem.waterOutput to highDensitySolidsPump.suction;

        connect remoteCommand to controlSystem.pumpCommand;
        connect controlSystem.pumpCommand to highDensitySolidsPump.speedCommand;
        connect controlSystem.hydraulicCommand to hydraulicPowerUnit.commandInput;
        connect controlSystem.flushCommand to flushWaterSystem.commandInput;

        connect highDensitySolidsPump.statusTelemetry to controlSystem.pumpTelemetry;
        connect hydraulicPowerUnit.telemetryOutput to controlSystem.hydraulicTelemetry;
        connect feedHopper.levelTelemetry to controlSystem.hopperTelemetry;
        connect controlSystem.supervisoryTelemetry to remoteTelemetry;

        perform action startSubsystem {
            first verifyFeedLevel;
            then energizeHydraulicPower;
            then primePump;
            then rampToFlowSetpoint;

            action verifyFeedLevel {
                out attribute permissiveGranted : Boolean;
            }

            action energizeHydraulicPower {
                out attribute hydraulicPressureReady : Boolean;
            }

            action primePump {
                out attribute pumpPrimed : Boolean;
            }

            action rampToFlowSetpoint {
                out attribute achievedFlowRate : FlowRate;
            }
        }

        perform action normalPumpOperation {
            in item feedSlurry : HighDensitySlurry;
            in attribute flowSetpoint : FlowRate;
            out item deliveredSlurry : HighDensitySlurry;
            out attribute actualFlowRate : FlowRate;
            out attribute actualDischargePressure : Pressure;

            first monitorSuctionConditions;
            then regulateHydraulicStrokeRate;
            then transferSlurry;
            then suppressPressurePulsation;
            then reportTelemetry;

            action monitorSuctionConditions;
            action regulateHydraulicStrokeRate;
            action transferSlurry;
            action suppressPressurePulsation;
            action reportTelemetry;
        }

        perform action shutdownSubsystem {
            first stopSlurryFeed;
            then reducePumpStrokeRate;
            then flushWetEnd;
            then depressurizeDischargeLine;
            then stopHydraulicPower;

            action stopSlurryFeed;
            action reducePumpStrokeRate;
            action flushWetEnd;
            action depressurizeDischargeLine;
            action stopHydraulicPower;
        }

        state machine subsystemMode {
            state Idle;
            state Starting;
            state Pumping;
            state Flushing;
            state ControlledShutdown;
            state Tripped;

            entry; then Idle;

            transition Idle_to_Starting
                first Idle
                accept start
                if feedHopper.currentLevel >= controlSystem.minimumHopperLevelPermissive
                then Starting;

            transition Starting_to_Pumping
                first Starting
                accept ready
                if hydraulicPowerUnit.systemPressure >= 18000000 [SI::pascal]
                then Pumping;

            transition Pumping_to_Flushing
                first Pumping
                accept flushRequest
                then Flushing;

            transition Pumping_to_ControlledShutdown
                first Pumping
                accept normalStop
                then ControlledShutdown;

            transition Pumping_to_Tripped
                first Pumping
                accept protectionTrip
                if highDensitySolidsPump.discharge.pressure >= controlSystem.highDischargePressureTrip
                then Tripped;

            transition Flushing_to_Idle
                first Flushing
                accept flushComplete
                then Idle;

            transition ControlledShutdown_to_Idle
                first ControlledShutdown
                accept shutdownComplete
                then Idle;

            transition Tripped_to_Idle
                first Tripped
                accept reset
                if highDensitySolidsPump.discharge.pressure < 500000 [SI::pascal]
                then Idle;
        }
    }

    requirement def MoveHighDensityFluidRequirement {
        doc /* The subsystem shall move high-density solids-bearing slurry from the feed interface to the delivery interface using a hydraulically driven high-density solids pump. */
        subject pumpingSubsystem : HighDensitySolidsPumpingSubsystem;
        require constraint {
            pumpingSubsystem.requiredFlowRate >= 0.05 [SI::cubicMetrePerSecond]
        }
    }

    requirement def DischargePressureRequirement {
        doc /* The subsystem shall provide sufficient pressure to overcome downstream pipeline losses and deliver slurry at the specified destination pressure. */
        subject pumpingSubsystem : HighDensitySolidsPumpingSubsystem;
        require constraint {
            pumpingSubsystem.requiredDischargePressure >= 12000000 [SI::pascal]
        }
    }

    requirement def SolidsHandlingRequirement {
        doc /* The pump wet end shall accept high-density slurry with high solids content without exceeding the allowable particle size and solids fraction limits. */
        subject pump : HighDensitySolidsPump;
        require constraint {
            pump.maximumSolidsMassFraction >= 0.70 and pump.maximumParticleDiameterD95 >= 0.010 [SI::metre]
        }
    }

    requirement def OverpressureProtectionRequirement {
        doc /* The subsystem shall transition to a tripped condition when discharge pressure exceeds the high-pressure trip limit. */
        subject pumpingSubsystem : HighDensitySolidsPumpingSubsystem;
        require constraint {
            pumpingSubsystem.controlSystem.highDischargePressureTrip <= pumpingSubsystem.dischargePipeline.designPressure
        }
    }

    requirement def FlushabilityRequirement {
        doc /* The subsystem shall provide a flush mode that clears the pump wet end and discharge line using service water after pumping high-density slurry. */
        subject pumpingSubsystem : HighDensitySolidsPumpingSubsystem;
        require constraint {
            pumpingSubsystem.flushWaterSystem.flushFlowRate >= 0.020 [SI::cubicMetrePerSecond]
        }
    }

    requirement def HydraulicPowerRequirement {
        doc /* The hydraulic power unit shall provide adequate hydraulic pressure and power to drive the high-density solids pump at rated flow and pressure. */
        subject hpu : HydraulicPowerUnit;
        require constraint {
            hpu.systemPressure >= 21000000 [SI::pascal] and hpu.motorRatedPower >= 300000 [SI::watt]
        }
    }

    requirement def AvailabilityRequirement {
        doc /* The pumping subsystem shall be designed for high availability in continuous industrial slurry transfer service. */
        subject pumpingSubsystem : HighDensitySolidsPumpingSubsystem;
        require constraint {
            pumpingSubsystem.minimumAvailability >= 96
        }
    }

    satisfy MoveHighDensityFluidRequirement by HighDensitySolidsPumpingSubsystem;
    satisfy DischargePressureRequirement by HighDensitySolidsPumpingSubsystem;
    satisfy SolidsHandlingRequirement by HighDensitySolidsPump;
    satisfy OverpressureProtectionRequirement by HighDensitySolidsPumpingSubsystem;
    satisfy FlushabilityRequirement by HighDensitySolidsPumpingSubsystem;
    satisfy HydraulicPowerRequirement by HydraulicPowerUnit;
    satisfy AvailabilityRequirement by HighDensitySolidsPumpingSubsystem;
}