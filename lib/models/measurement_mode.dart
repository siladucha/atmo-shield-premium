enum MeasurementMode {
  quick,
  accurate;

  int get duration => this == MeasurementMode.quick ? 30 : 60;
  
  String get displayName => this == MeasurementMode.quick ? 'Quick Mode' : 'Accurate Mode';
  
  String get description => this == MeasurementMode.quick 
      ? '30 seconds • HR only' 
      : '60 seconds • HR + HRV';
}
