package 'Precision Heat Pen' {
	private import ScalarValues::*;
	private import SI::*;

	item def PowerOnSignal;
	item def PressureSignal {
		attribute isPressed : Boolean;
	}
	item def TemperatureReading {
		attribute measuredTemp : Real;
	}
	item def PowerCommand {
		attribute level : Real;
	}
	item def UserSetting {
		attribute targetTemp : Real;
		attribute mode : String;
	}
	item def StatusReport {
		attribute condition : String;
		attribute currentTemp : Real;
	}
	item def FaultSignal {
		attribute code : String;
	}

	part def PowerSupplyUnit {
		port acIn { in ac : Real; }
		port dcOut { out dc : Real; }
	}

	part def PressureSensorAssembly {
		port pressureOut { out pressure : PressureSignal; }
	}

	part def TemperatureSensor {
		port tempOut { out temp : TemperatureReading; }
	}

	part def HeatingElementAssembly {
		port powerIn { in power : Real; }
		port cmdIn { in cmd : PowerCommand; }
		port tempOut { out temp : TemperatureReading; }
		port heatOut { out heat : Real; }
		part integratedTempSensor : TemperatureSensor;
		connect integratedTempSensor.tempOut to tempOut;
	}

	part def TipModule {
		attribute material : String = "Copper-Iron Alloy";
		port heatIn { in heat : Real; }
	}

	part def UserInterfacePanel {
		port settingOut { out setting : UserSetting; }
		port resetOut { out reset : PowerOnSignal; }
		port statusIn { in status : StatusReport; }
		port faultIn { in fault : FaultSignal; }
		attribute displayType : String = "LED";
	}

	part def ControllerModule {
		port powerIn { in power : Real; }
		port pressureIn { in pressure : PressureSignal; }
		port tempIn { in temp : TemperatureReading; }
		port uiIn { in setting : UserSetting; }
		port cmdOut { out cmd : PowerCommand; }
		port statusOut { out status : StatusReport; }
		port faultOut { out fault : FaultSignal; }
		port resetIn { in reset : PowerOnSignal; }

		attribute targetTemp : Real = 350;
		attribute maxSafeTemp : Real = 450;

		state ControllerBehavior {
			entry; then standby;

			state standby {
				do action ceaseOutput { /* Stop heating output */ }
			}
			accept setting : UserSetting via uiIn
				then standby;
			accept pressure : PressureSignal via pressureIn
				if pressure.isPressed
				then preheating;

			state preheating {
				do action applyFullHeat { /* Apply full power to heating element */ }
			}
			accept temp : TemperatureReading via tempIn
				if temp.measuredTemp >= targetTemp
				then operational;
			accept temp : TemperatureReading via tempIn
				if temp.measuredTemp > maxSafeTemp
				then fault;
			accept pressure : PressureSignal via pressureIn
				if not pressure.isPressed
				then cooldown;

			state operational {
				do action maintainHeat { /* Closed-loop PID control to maintain target temperature */ }
			}
			accept pressure : PressureSignal via pressureIn
				if not pressure.isPressed
				then cooldown;
			accept temp : TemperatureReading via tempIn
				if temp.measuredTemp > maxSafeTemp
				then fault;

			state cooldown {
				do action ceaseOutput { /* Stop heating and allow natural cooldown */ }
			}
			accept after 10 [SI::s]
				then standby;
			accept temp : TemperatureReading via tempIn
				if temp.measuredTemp < 50
				then standby;

			state fault {
				do action handleFault { /* Cease output, report fault status, and signal fault code */ }
			}
			accept reset : PowerOnSignal via resetIn
				then standby;
		}
	}

	part def HeatPen {
		port acInput { in ac : Real; }

		part psu : PowerSupplyUnit;
		part controller : ControllerModule;
		part pressureSensor : PressureSensorAssembly;
		part heatingElement : HeatingElementAssembly;
		part tip : TipModule;
		part uiPanel : UserInterfacePanel;

		bind acInput = psu.acIn;
		connect psu.dcOut to controller.powerIn;
		connect psu.dcOut to heatingElement.powerIn;
		connect pressureSensor.pressureOut to controller.pressureIn;
		connect heatingElement.tempOut to controller.tempIn;
		connect heatingElement.heatOut to tip.heatIn;
		connect controller.cmdOut to heatingElement.cmdIn;
		connect uiPanel.settingOut to controller.uiIn;
		connect uiPanel.resetOut to controller.resetIn;
		connect controller.statusOut to uiPanel.statusIn;
		connect controller.faultOut to uiPanel.faultIn;
	}

	requirement def ReqPressureActivated {
		doc
		/* The Heat Pen shall only generate heat when the Pressure Sensor Assembly detects that the tip is pressed against a work surface. */
	}
	requirement def ReqClosedLoopControl {
		doc
		/* The Controller Module shall use temperature sensor feedback to rapidly reach and precisely maintain the user-defined target temperature. */
	}
	requirement def ReqSafetyStates {
		doc
		/* The system shall enter a fault state upon detecting overheating and a cooldown state when the tip is lifted from the work surface. */
	}
	requirement def ReqTipMaterial {
		doc
		/* The Tip Module shall be constructed from a thermally conductive copper-iron alloy shaped for precision work. */
	}
	requirement def ReqSafeVoltage {
		doc
		/* The Power Supply Unit shall convert standard wall voltage to a safe low operating voltage for the pen. */
	}
}
