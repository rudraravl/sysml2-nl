package IPC_System {
    private import ISQ::PressureValue;
    private import ISQ::DurationValue;
    private import SI::Pa;
    private import SI::s;

    attribute def CompressorCommand;
    attribute def ValveCommand;
    attribute def EmergencyStop;
    attribute def StartTherapy;
    item def PressurizedAir;

    part def Patient;

    part def Controller {
        attribute inflationDuration : DurationValue = 5 [s];
        attribute holdDuration : DurationValue = 10 [s];
        attribute deflationDuration : DurationValue = 3 [s];
        attribute restDuration : DurationValue = 5 [s];
        attribute targetTherapeuticPressure : PressureValue = 5000 [Pa];
        
        port compressorCommandPort {
            out compressorCommand : CompressorCommand;
        }
        port valveCommandPort {
            out valveCommand : ValveCommand;
        }
        port sensedPressurePort {
            in sensedPressure : PressureValue;
        }
        port emergencyStopPort {
            in emergencyStop : EmergencyStop;
        }
        
        exhibit state controllerStates {
            entry; then idle;
            state idle;
            accept StartTherapy
                do send new CompressorCommand() to compressorCommandPort
                then inflatingDistal;
            state inflatingDistal {
                entry do send new ValveCommand() to valveCommandPort;
                accept after inflationDuration
                    then inflatingMiddle;
            }
            state inflatingMiddle {
                entry do send new ValveCommand() to valveCommandPort;
                accept after inflationDuration
                    then inflatingProximal;
            }
            state inflatingProximal {
                entry do send new ValveCommand() to valveCommandPort;
                accept after inflationDuration
                    then holding;
            }
            state holding {
                accept after holdDuration
                    then deflating;
            }
            state deflating {
                entry do send new ValveCommand() to valveCommandPort;
                accept after deflationDuration
                    then resting;
            }
            state resting {
                accept after restDuration
                    then inflatingDistal;
                accept EmergencyStop
                    then emergencyStopped;
            }
            state emergencyStopped;
        }
    }

    part def AirCompressor {
        port compressorCommandPort {
            in compressorCommand : CompressorCommand;
        }
        port pressurizedAirPort {
            out pressurizedAir : PressurizedAir;
        }
    }

    part def ValveManifold {
        port pressurizedAirPort {
            in pressurizedAir : PressurizedAir;
        }
        port valveCommandPort {
            in valveCommand : ValveCommand;
        }
        port chamberAirPort {
            out chamberAir : PressurizedAir;
        }
    }

    part def Chamber;

    part def CompressionSleeve {
        port chamberAirPort {
            in chamberAir : PressurizedAir;
        }
        port sleevePressurePort {
            out sleevePressure : PressureValue;
        }
        part distalChamber : Chamber;
        part middleChamber : Chamber;
        part proximalChamber : Chamber;
    }

    part def PressureSensor {
        port sleevePressurePort {
            in sleevePressure : PressureValue;
        }
        port sensedPressurePort {
            out sensedPressure : PressureValue;
        }
    }

    part def SafetyMonitor {
        attribute maxSafePressure : PressureValue = 10000 [Pa];
        port sensedPressurePort {
            in sensedPressure : PressureValue;
        }
        port emergencyStopPort {
            out emergencyStop : EmergencyStop;
        }
        
        exhibit state safetyMonitorStates {
            entry; then monitoring;
            state monitoring;
            accept when sensedPressurePort.sensedPressure > maxSafePressure
                do send new EmergencyStop() to emergencyStopPort
                then emergencyShutdown;
            state emergencyShutdown;
        }
    }

    part def IPCSystem {
        part patient : Patient;
        
        part controller : Controller;
        part airCompressor : AirCompressor;
        part valveManifold : ValveManifold;
        part compressionSleeve : CompressionSleeve;
        part pressureSensor : PressureSensor;
        part safetyMonitor : SafetyMonitor;

        interface controllerToCompressor connect controller.compressorCommandPort to airCompressor.compressorCommandPort {
            flow compressorCommandFlow of CompressorCommand 
                from controller.compressorCommandPort.compressorCommand to airCompressor.compressorCommandPort.compressorCommand;
        }
        interface compressorToManifold connect airCompressor.pressurizedAirPort to valveManifold.pressurizedAirPort {
            flow pressurizedAirFlow of PressurizedAir 
                from airCompressor.pressurizedAirPort.pressurizedAir to valveManifold.pressurizedAirPort.pressurizedAir;
        }
        interface controllerToManifold connect controller.valveCommandPort to valveManifold.valveCommandPort {
            flow valveCommandFlow of ValveCommand 
                from controller.valveCommandPort.valveCommand to valveManifold.valveCommandPort.valveCommand;
        }
        interface manifoldToSleeve connect valveManifold.chamberAirPort to compressionSleeve.chamberAirPort {
            flow chamberAirFlow of PressurizedAir 
                from valveManifold.chamberAirPort.chamberAir to compressionSleeve.chamberAirPort.chamberAir;
        }
        interface sleeveToSensor connect compressionSleeve.sleevePressurePort to pressureSensor.sleevePressurePort {
            flow sleevePressureFlow of PressureValue 
                from compressionSleeve.sleevePressurePort.sleevePressure to pressureSensor.sleevePressurePort.sleevePressure;
        }
        interface sensorToController connect pressureSensor.sensedPressurePort to controller.sensedPressurePort {
            flow sensedPressureFlow of PressureValue 
                from pressureSensor.sensedPressurePort.sensedPressure to controller.sensedPressurePort.sensedPressure;
        }
        interface sensorToSafetyMonitor connect pressureSensor.sensedPressurePort to safetyMonitor.sensedPressurePort {
            flow sensedPressureSafetyFlow of PressureValue 
                from pressureSensor.sensedPressurePort.sensedPressure to safetyMonitor.sensedPressurePort.sensedPressure;
        }
        interface safetyMonitorToController connect safetyMonitor.emergencyStopPort to controller.emergencyStopPort {
            flow emergencyStopFlow of EmergencyStop 
                from safetyMonitor.emergencyStopPort.emergencyStop to controller.emergencyStopPort.emergencyStop;
        }
    }

    requirement def IPCSystemRequirements {
        requirement preventDVT {
            doc /* The system shall prevent deep vein thrombosis by enhancing blood flow. */
        }
        requirement executeTherapeuticCycle {
            doc /* The controller shall execute a cycle of sequential inflation, hold, deflation, and rest. */
        }
        requirement emergencyShutdown {
            doc /* The safety monitor shall trigger an emergency shutdown if pressure exceeds maxSafePressure. */
        }
    }
}
