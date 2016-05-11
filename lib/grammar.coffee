module.exports =
  name: 'Narrow buffer'
  scopeName: 'source.narrow'
  fileTypes: []
  patterns: [
    {
      match: '^\\s*(\\d+):(?:(\\d+):)*'
      name: 'location.narrow'
      captures:
        '1':
          name: 'constant.numeric.line.narrow'
        '2':
          name: 'constant.numeric.column.narrow'
    }
    {
      begin: '^(#{2})(\\s*)'
      end: '$'
      name: 'markup.heading.heading-2.narrow'
      captures:
        '1':
          name: 'markup.heading.marker.narrow'
        '2':
          name: 'markup.heading.space.narrow'
      patterns: [
        {
          include: '$self'
        }
      ]
    }
    {
      begin: '^(#{1})(\\s*)'
      end: '$'
      name: 'markup.heading.heading-1.narrow'
      captures:
        '1':
          name: 'markup.heading.marker.narrow'
        '2':
          name: 'markup.heading.space.narrow'
      patterns: [
        {
          include: '$self'
        }
      ]
    }
  ]
