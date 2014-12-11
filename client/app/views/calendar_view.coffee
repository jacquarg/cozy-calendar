app = require 'application'
BaseView = require 'lib/base_view'
EventPopover = require './calendar_popover_event'
Header = require './calendar_header'
helpers = require 'helpers'
timezones = require('helpers/timezone').timezones

Event = require 'models/event'

module.exports = class CalendarView extends BaseView

    id: 'view-container'
    template: require './templates/calendarview'

    initialize: (@options) ->

        @eventCollection = @model.events
        @listenTo @eventCollection, 'add'  , @refresh
        @listenTo @eventCollection, 'reset', @refresh
        @listenTo @eventCollection, 'remove', @onRemove
        @listenTo @eventCollection, 'change', @refreshOne
        @model = null

        @calendarsCollection = app.calendars
        @listenTo @calendarsCollection, 'change', @refresh

    afterRender: ->
        locale = moment.localeData()

        @cal = @$ '#alarms'
        @view = @options.view
        @cal.fullCalendar
            lang: window.locale
            header: false
            firstDay: 1 # first day of the week is monday
            height: "auto"
            defaultView: @view
            year: @options.year
            month: @options.month
            date: @options.date
            viewRender: @onChangeView
            #i18n with momentjs.
            monthNames: locale._months
            monthNamesShort: locale._monthsShort
            dayNames: locale._weekdays
            dayNamesShort: locale._weekdaysShort
            buttonText:
                today: t('today')
                month: t('month')
                week:  t('week')
                day:   t('day')

            # Display time in the cozy's user timezone.
            # time given by Fullcalendar are ambiguous moments,
            # with cozy's user timezone values.
            # Cf http://fullcalendar.io/docs/timezone/timezone/
            timezone: window.app.timezone
            timeFormat: '' # Setted in scheduleitem title.
            columnFormat:
                'week': 'ddd D'
                'month': 'dddd'

            axisFormat: 'H:mm'
            allDaySlot: true
            selectable: true
            selectHelper: false
            unselectAuto: false
            eventRender: @onEventRender
            select: @onSelect
            eventDragStop: @onEventDragStop
            eventDrop: @onEventDrop
            eventClick: @onEventClick
            eventResizeStop: @onEventResizeStop
            eventResize: @onEventResize
            handleWindowResize: false

        source = @eventCollection.getFCEventSource @calendarsCollection
        @cal.fullCalendar 'addEventSource', source

        @calHeader = new Header cal: @cal

        @calHeader.on 'next', => @cal.fullCalendar 'next'
        @calHeader.on 'prev', => @cal.fullCalendar 'prev'
        @calHeader.on 'today', => @cal.fullCalendar 'today'
        @calHeader.on 'week', => @cal.fullCalendar 'changeView', 'agendaWeek'
        @calHeader.on 'month', => @cal.fullCalendar 'changeView', 'month'
        @calHeader.on 'list', -> app.router.navigate 'list', trigger:true
        @$('#alarms').prepend @calHeader.render().$el

        @handleWindowResize()
        debounced = _.debounce @handleWindowResize, 10
        $(window).resize (ev) -> debounced() if ev.target is window

    remove: ->
        @popover?.close()
        super


    handleWindowResize: (initial) =>
        if $(window).width() > 1000
            targetHeight = $(window).height() - 90
            $("#menu").height targetHeight + 90
        else if $(window).width() > 600
            targetHeight = $(window).height() - 100
            $("#menu").height targetHeight + 100
        else
            targetHeight = $(window).height() - 50
            $("#menu").height 40

        unless initial is 'initial'
            @cal.fullCalendar 'option', 'height', targetHeight
        fcHeaderHeight = @$('.fc-header').height()
        fcViewContainreHeight = @$('.fc-view-container').height()
        @cal.height fcHeaderHeight + fcViewContainreHeight

    refresh: (collection) ->
        console.log "cal_view refresh"
        @cal.fullCalendar 'refetchEvents'

    onRemove: (model) ->
        @cal.fullCalendar 'removeEvents', model.cid

    refreshOne: (model) =>
        return @refresh() if model.isRecurrent()

        # fullCalendar('updateEvent') eats end of allDay events!(?),
        # perform a full refresh as a workaround.
        return @refresh() if model.isAllDay()

        data = model.toPunctualFullCalendarEvent()
        [fcEvent] = @cal.fullCalendar 'clientEvents', data.id
        # if updated event is not shown on screen, fcEvent doesn't exist
        if fcEvent?
            _.extend fcEvent, data
            @cal.fullCalendar 'updateEvent', fcEvent

    showPopover: (options) ->
        options.container = @cal
        options.parentView = @

        if @popover
            @popover.close()

            # click on same case
            if @popover.options? and (@popover.options.model? and \
               @popover.options.model is options.model or \
               (@popover.options.start?.isSame(options.start) and \
               @popover.options.end?.isSame(options.end) and \
               @popover.options.type is options.type))

                @cal.fullCalendar 'unselect'
                @popover = null
                return

        @popover = if options.type is 'event' then new EventPopover options
        @popover.render()

    onChangeView: (view) =>
        @calHeader?.render()
        if @view isnt view.name
            @handleWindowResize()

        @view = view.name

        f = if @view is 'month' then '[month]/YYYY/M' else '[week]/YYYY/M/D'
        hash = view.intervalStart.format f

        app.router.navigate hash

    getUrlHash: =>
        switch @cal.fullCalendar('getView').name
            when 'month' then 'calendar'
            when 'agendaWeek' then 'calendarweek'

    onSelect: (startDate, endDate, jsEvent, view) =>
        # In month view, default to 10:00 - 11:00 instead of fullday event.
        if @view is 'month'
            # startDate and endDate are dates, we add time part to create an
            # ambiguous date string.

            # endDate has +1 day for an unknown reason
            endDate.subtract 1, 'days'
            startDate = startDate.format() + 'T10:00:00.000'
            endDate = endDate.format() + 'T11:00:00.000'

        start = helpers.ambiguousToTimezoned startDate
        end = helpers.ambiguousToTimezoned endDate
        @showPopover
            type: 'event'
            start: start
            end: end
            target: $ jsEvent.target

    onPopoverClose: ->
        @cal.fullCalendar 'unselect'
        @popover = null

    onEventRender: (event, element) ->
        if event.isSaving? and event.isSaving
            spinTarget = $(element).find '.fc-event-time'
            spinTarget.addClass 'spinning'
            spinTarget.html "&nbsp;"
            spinTarget.spin "tiny"

        $(element).attr 'title', event.title

        return element

    onEventDragStop: (event, jsEvent, ui, view) ->
        event.isSaving = true

    onEventDrop: (fcEvent, delta, revertFunc, jsEvent, ui, view) =>
        evt = @eventCollection.get fcEvent.id
        evt.addToStart(delta)
        evt.addToEnd(delta)

        evt.save {},
            wait: true
            success: ->
                fcEvent.isSaving = false
            error: ->
                fcEvent.isSaving = false
                revertFunc()

    onEventResizeStop: (fcEvent, jsEvent, ui, view) ->
        fcEvent.isSaving = true

    onEventResize: (fcEvent, delta, revertFunc, jsEvent, ui, view) =>

        model = @eventCollection.get fcEvent.id
        model.addToEnd delta

        model.save {},
            wait: true
            success: ->
                fcEvent.isSaving = false

            error: ->
                fcEvent.isSaving = false
                revertFunc()


    onEventClick: (fcEvent, jsEvent, view) =>
        return true if $(jsEvent.target).hasClass 'ui-resizable-handle'

        model = if fcEvent.type is 'event' then @eventCollection.get fcEvent.id
        else throw new Error('wrong typed event in fc')

        @showPopover
            type: model.fcEventType
            model: model
            target: $(jsEvent.currentTarget)
