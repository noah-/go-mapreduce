package mapreduce

// A sequential master executes a MapReduce job on a single worker.
type SequentialMaster struct {
	JobName        string
	InputFileNames []string
	NumReducers    uint
	MapF           MapFunction
	ReduceF        ReduceFunction

	active bool // Whether this master is active or not.
}

// Constructs a new sequential master with the given inputs.
func NewSequentialMaster(jobName string, inputFileNames []string,
	numReducers uint, mapF MapFunction, reduceF ReduceFunction) *SequentialMaster {
	return &SequentialMaster{
		JobName:        jobName,
		InputFileNames: inputFileNames,
		NumReducers:    numReducers,
		MapF:           mapF,
		ReduceF:        reduceF,
		active:         false,
	}
}

// Used by workers over RPC: registers the worker with `workerAddress`. After
// registration, the master begins giving work to the worker. Sequential masters
// do not listen over a network, so this function panics if called.
func (s *SequentialMaster) Register(workerAddress string) {
	panic("Registration should not occur in sequential master!")
}

// Starts the master. Spins up a worker, schedules tasks, and blocks until the
// job has completed.
func (m *SequentialMaster) Start() {
	m.active = true

	w := *NewWorker(m.JobName, m.MapF, m.ReduceF)

	for i, file := range m.InputFileNames {
		w.DoMap(file, uint(i), m.NumReducers);
	}

	for i := uint(0); i < m.NumReducers; i++ {
		w.DoReduce(i, uint(len(m.InputFileNames)))
	}
}

// Merges the output of all reduce tasks into one file. Returns the filename for
// the merged output.
func (m *SequentialMaster) Merge() string {
	mergeReduceOutputs(m.JobName, m.NumReducers)
	return MergeOutputName(m.JobName)
}

// Shuts the master down.
func (m *SequentialMaster) Shutdown() {
	m.active = false
}

// Returns whether this master is running a job at the moment.
func (m *SequentialMaster) IsActive() bool {
	return m.active
}
