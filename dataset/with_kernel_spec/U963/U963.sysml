package AerobotSystem {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    item def LiftingGas;
    item def BallastMass;
    item def ScienceData;
    item def ImageData;
    item def SpectralData;
    item def ParticleCountData;
    item def AtmosphericData;
    item def CommandData;
    item def TelemetryData;

    attribute def TemperatureValue :> Real;
    attribute def PressureValue :> Real;
    attribute def WindSpeedValue :> Real;
    attribute def AltitudeValue :> Real;
    attribute def MassValue :> Real;
    attribute def PowerValue :> Real;
    attribute def EnergyValue :> Real;
    attribute def VolumeValue :> Real;

    port def GasControlPort {
        in attribute targetLift : Real;
        out attribute currentLift : Real;
    }
    port def BallastControlPort {
        in attribute releaseCommand : Boolean;
        out attribute remainingBallast : MassValue;
    }
    port def PowerPort {
        out attribute power : PowerValue;
        in attribute demand : PowerValue;
    }
    port def DataPort {
        in item dataIn : CommandData;
        out item dataOut : TelemetryData;
    }
    port def ScienceDataPort {
        out item scienceOut : ScienceData;
    }
    port def AtmosphericDataPort {
        out attribute temperature : TemperatureValue;
        out attribute pressure : PressureValue;
        out attribute windSpeed : WindSpeedValue;
        out attribute windDirection : Real;
    }
    port def NavigationDataPort {
        out attribute currentAltitude : AltitudeValue;
        out attribute currentPosition : Real;
        in attribute targetAltitude : AltitudeValue;
        in attribute targetPosition : Real;
    }

    part def BalloonEnvelope {
        attribute volume : VolumeValue;
        attribute maxVolume : VolumeValue;
        attribute gasMass : MassValue;
        port gasControlPort : GasControlPort;
        out item liftingGas : LiftingGas;
    }

    part def BallastSystem {
        attribute totalBallastMass : MassValue;
        attribute remainingMass : MassValue;
        port ballastControlPort : BallastControlPort;
        port powerIn : ~PowerPort;
        item ballast : BallastMass;
        perform action releaseBallast {
            in attribute amount : MassValue;
            out attribute released : MassValue;
            first start;
            then action valveOpen;
            then action massEject;
            then done;
        }
    }

    part def BuoyancyController {
        attribute currentAltitude : AltitudeValue;
        attribute targetAltitude : AltitudeValue;
        port gasControlPort : ~GasControlPort;
        port ballastControlPort : ~BallastControlPort;
        port navDataPort : ~NavigationDataPort;
        port powerIn : ~PowerPort;
        perform action controlAltitude {
            in attribute currentAlt : AltitudeValue;
            in attribute targetAlt : AltitudeValue;
            out attribute liftCommand : Real;
            out attribute ballastCommand : Boolean;
            first start;
            then action compareAltitude;
            then action determineAction;
            then done;
        }
    }

    part def ScienceInstrumentPackage {
        attribute instrumentCount : Integer;
        port scienceDataPort : ScienceDataPort;
        port powerIn : ~PowerPort;
        perform action collectScience {
            out item images : ImageData;
            out item spectra : SpectralData;
            out item particleCounts : ParticleCountData;
            first start;
            then action captureImage;
            then action performSpectralAnalysis;
            then action countParticles;
            then done;
        }
    }

    part def AtmosphericSensorSuite {
        port atmosphericDataPort : AtmosphericDataPort;
        port powerIn : ~PowerPort;
        perform action measureEnvironment {
            out attribute temperature : TemperatureValue;
            out attribute pressure : PressureValue;
            out attribute windSpeed : WindSpeedValue;
            out attribute windDirection : Real;
            first start;
            then action measureTemperature;
            then action measurePressure;
            then action measureWind;
            then done;
        }
    }

    part def SolarPanel {
        attribute area : Real;
        attribute efficiency : Real;
        attribute outputPower : PowerValue;
        perform action generatePower {
            out attribute power : PowerValue;
        }
    }

    part def RechargeableBattery {
        attribute capacity : EnergyValue;
        attribute currentCharge : EnergyValue;
        attribute chargeLevel : Real = currentCharge / capacity;
        port powerPort : PowerPort;
        perform action managePower {
            in attribute demand : PowerValue;
            out attribute supplied : PowerValue;
            first start;
            then action checkCharge;
            then action distributePower;
            then done;
        }
    }

    part def PowerSystem {
        part solarPanels[4] : SolarPanel;
        part battery : RechargeableBattery;
        port powerOutPort : PowerPort;
        perform action regulatePower {
            in attribute totalDemand : PowerValue;
            out attribute totalSupply : PowerValue;
            first start;
            then action harvestSolar;
            then action chargeBattery;
            then action distributeToSubsystems;
            then done;
        }
    }

    part def NavigationSubsystem {
        attribute currentPosition : Real;
        attribute currentAltitude : AltitudeValue;
        attribute targetPosition : Real;
        attribute targetAltitude : AltitudeValue;
        port navDataPort : NavigationDataPort;
        port atmosphericDataPort : ~AtmosphericDataPort;
        port powerIn : ~PowerPort;
        perform action navigate {
            in attribute windSpeed : WindSpeedValue;
            in attribute windDirection : Real;
            in attribute currentPos : Real;
            in attribute targetPos : Real;
            out attribute requiredAltitude : AltitudeValue;
            first start;
            then action determineWindLayer;
            then action calculateAltitudeChange;
            then action setWaypoint;
            then done;
        }
    }

    part def CommunicationSubsystem {
        port dataPort : DataPort;
        port powerIn : ~PowerPort;
        port scienceIn : ~ScienceDataPort;
        perform action transmitData {
            in item science : ScienceData;
            in item telemetry : TelemetryData;
            out item transmitted : TelemetryData;
            first start;
            then action encodeData;
            then action sendTransmission;
            then done;
        }
        perform action receiveCommands {
            out item commands : CommandData;
            first start;
            then action listenForCommands;
            then action decodeCommands;
            then done;
        }
    }

    part def Gondola {
        part scienceInstrumentPackage : ScienceInstrumentPackage;
        part atmosphericSensorSuite : AtmosphericSensorSuite;
        part powerSystem : PowerSystem;
        part navigationSubsystem : NavigationSubsystem;
        part communicationSubsystem : CommunicationSubsystem;
        part buoyancyController : BuoyancyController;
        part ballastSystem : BallastSystem;
        attribute totalMass : MassValue;
    }

    part def Aerobot {
        attribute vehicleMass : MassValue;
        attribute operationalAltitude : AltitudeValue;
        attribute missionDuration : Real;
        part balloonEnvelope : BalloonEnvelope;
        part gondola : Gondola;
        port commPort : DataPort;
        
        attribute def SigLaunch;
        attribute def SigReachOperationalAltitude;
        attribute def SigMissionComplete;
        attribute def SigMeasureComplete;
        attribute def SigScienceComplete;
        attribute def SigNavigationComplete;
        attribute def SigTransmitComplete;
        attribute def SigLand;

        state missionStateMachine {
            entry; then standby;
            state standby;
            accept SigLaunch then ascent;
            state ascent;
            accept SigReachOperationalAltitude then cruise;
            state cruise {
                entry; then measuring;
                state measuring;
                accept SigMeasureComplete then collectingScience;
                state collectingScience;
                accept SigScienceComplete then navigating;
                state navigating;
                accept SigNavigationComplete then transmitting;
                state transmitting;
                accept SigTransmitComplete then measuring;
            }
            accept SigMissionComplete then descent;
            state descent;
            accept SigLand then landed;
            state landed;
        }
    }

    part aerobotSystem : Aerobot {
        :>> operationalAltitude = 50000[m];
        :>> missionDuration = 30;
        :>> vehicleMass = 200[kg];

        part balloonEnvelope : BalloonEnvelope {
            :>> volume = 30000[m*m*m];
            :>> maxVolume = 35000[m*m*m];
            :>> gasMass = 50[kg];
        }

        part gondola : Gondola {
            :>> totalMass = 200[kg];

            part scienceInstrumentPackage : ScienceInstrumentPackage {
                :>> instrumentCount = 5;
            }

            part atmosphericSensorSuite : AtmosphericSensorSuite;

            part powerSystem : PowerSystem {
                part solarPanels[4] : SolarPanel {
                    :>> area = 2.0;
                    :>> efficiency = 0.3;
                    :>> outputPower = 300[W];
                }
                part battery : RechargeableBattery {
                    :>> capacity = 5000000[J];
                    :>> currentCharge = 5000000[J];
                }
            }

            part navigationSubsystem : NavigationSubsystem;

            part communicationSubsystem : CommunicationSubsystem;

            part buoyancyController : BuoyancyController;

            part ballastSystem : BallastSystem {
                :>> totalBallastMass = 30[kg];
                :>> remainingMass = 30[kg];
            }

            connect atmosphericSensorSuite.atmosphericDataPort to navigationSubsystem.atmosphericDataPort;
            connect buoyancyController.navDataPort to navigationSubsystem.navDataPort;
            connect powerSystem.powerOutPort to scienceInstrumentPackage.powerIn;
            connect powerSystem.powerOutPort to atmosphericSensorSuite.powerIn;
            connect powerSystem.powerOutPort to navigationSubsystem.powerIn;
            connect powerSystem.powerOutPort to communicationSubsystem.powerIn;
            connect powerSystem.powerOutPort to buoyancyController.powerIn;
            connect powerSystem.powerOutPort to ballastSystem.powerIn;
            connect scienceInstrumentPackage.scienceDataPort to communicationSubsystem.scienceIn;
            connect buoyancyController.ballastControlPort to ballastSystem.ballastControlPort;
            
            flow of science : ScienceData
                from scienceInstrumentPackage.scienceDataPort.scienceOut to communicationSubsystem.scienceIn;
        }

        connect gondola.buoyancyController.gasControlPort to balloonEnvelope.gasControlPort;
        connect gondola.communicationSubsystem.dataPort to commPort;
        
        flow of telemetry : TelemetryData
            from gondola.communicationSubsystem.dataPort.dataOut to commPort.dataOut;
    }

    requirement def LongDurationFlight {
        attribute minMissionDuration : Real = 30;
        subject aerobot : Aerobot;
        doc /* The mission duration shall be greater than or equal to 30 days. */
    }

    requirement def AutonomousNavigation {
        subject navigationSubsystem : NavigationSubsystem;
        doc /* The navigation subsystem shall autonomously navigate to target waypoints. */
    }

    requirement def ScienceDataCollection {
        subject scienceInstrumentPackage : ScienceInstrumentPackage;
        doc /* The science instrument package shall collect images, spectral data, and particle counts. */
    }

    requirement def AltitudeControl {
        attribute maxAltitudeError : AltitudeValue = 500[m];
        subject buoyancyController : BuoyancyController;
        doc /* The buoyancy controller shall maintain altitude within the maximum error. */
    }

    requirement longDurationFlightReq : LongDurationFlight {
        subject :>> aerobot = aerobotSystem;
    }

    requirement autonomousNavigationReq : AutonomousNavigation {
        subject :>> navigationSubsystem = aerobotSystem.gondola.navigationSubsystem;
    }

    requirement scienceDataCollectionReq : ScienceDataCollection {
        subject :>> scienceInstrumentPackage = aerobotSystem.gondola.scienceInstrumentPackage;
    }

    requirement altitudeControlReq : AltitudeControl {
        subject :>> buoyancyController = aerobotSystem.gondola.buoyancyController;
    }
}
