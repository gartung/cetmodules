#[================================================================[.rst:
BasicPlugin
===========

Module defining the function :cmake:command:`basic_plugin` to generate a generic
plugin module.
#]================================================================]

# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetPackagePath)
include(CetProcessLiblist)
include(CetRegexEscape)

set(cet_bp_flags ALLOW_UNDERSCORES BASENAME_ONLY NOP NO_EXPORT NO_INSTALL
  USE_BOOST_UNIT USE_PRODUCT_NAME VERSION)
set(cet_bp_one_arg_opts EXPORT_SET SOVERSION)
set(cet_bp_list_options ALIAS IMPL_SOURCE LIBRARIES LOCAL_INCLUDE_DIRS
  REG_SOURCE SOURCE)

cet_regex_escape(${cet_bp_flags} ${cet_bp_one_arg_opts} ${cet_bp_list_options} VAR _e_bp_args)
string(REPLACE ";" "|" _e_bp_args "${_e_bp_args}")

#[================================================================[.rst:
.. cmake:command:: basic_plugin

   Create a plugin library, with or without a separate registration
   library to avoid One Definition Rule (ODR) violations.

   **Synopsis:**
     .. code-block:: cmake

        basic_plugin(<name> <suffix> [<options>])

   **Source specification options:**

     ``IMPL_SOURCE <implementation-source>...`` Specify source to
       compile into the plugin's interface implementation library, if
       appropriate. The implementation should *not* invoke any
       registration definition macros or the ODR will be violated.

     ``REG_SOURCE <registration-source>...``
       Specify source to compile into the plugin registration library,
       intended only for runtime injection (via *e.g.* ``dlopen()``)
       into an executable, and not for dynamic linking.

     .. note::

        * If ``REG_SOURCE`` is omitted, we look for ``<name>_<suffix>.cc``

        * If ``IMPL_SOURCE`` is omitted, we look for ``<name>.cc``

   **Dependency specification options:**

     ``LIBRARIES [INTERFACE|PRIVATE|PROTECTED|PUBLIC|REG] <library-dependency>...``

       Specify targets and/or libraries upon which the implementation
       (``INTERFACE``, ``PUBLIC``, ``PRIVATE``), or registration
       (``REG``) libraries should depend. If implementation and
       registration share a dependency not inherited by public callers
       of the implementation, specify the library as both ``PRIVATE``
       and ``REG``.

     .. note::

        * The registration library has an automatic dependence on the
          implementation library (if present).

        * If ``PUBLIC`` or ``INTERFACE`` dependencies are specified and
          there is no implementation source, then the library will be
          built shared rather than as a module, and all responsibility
          for ODR violations rests with the library builder.

        * An additional dependency designation, ``CONDITIONAL``, is
          accepted and is intended for use by intermediate functions
          adding dependencies to a library. ``CONDITIONAL`` is identical
          to ``PUBLIC`` without making a statement about the shared or
          module nature of the combined implementation/registration
          library or the presence of a public (non-plugin) calling
          interface.

   **Other options:**

     ``ALIAS <alias>...``
       Create the specified CMake alias targets to the implementation
       library.

     ``ALLOW_UNDERSCORES``
       Normally, neither ``<name>`` nor ``<suffix>`` may contain
       underscores in order to avoid possible ambiguities. Allow them
       with this option at your own risk.

     ``BASENAME_ONLY``
       Do not add the relative path (directories delimited by ``_``) to
       the front of the plugin library name.

     ``EXPORT_SET <export-name>``
       Add the library to the ``<export-name>`` export set.

     ``LOCAL_INCLUDE_DIRS <dir>...``
       Headers may be found in ``<dir>``... at build time.

     ``NOP``
       Option / argument disambiguator; no other function.

     ``NO_EXPORT``

     ``NO_INSTALL``
       Do not install the generated library or libraries.

     ``SOVERSION <version>``
       The library's compatibility version (*cf*
       :cmake:prop_tgt:`SOVERSION`).

     ``USE_BOOST_UNIT``
       The plugin uses Boost unit test functions and should be compiled
       and linked accordingly.

     ``USE_PACKAGE_NAME``
       The package name will be prepended to the plugin library name,
       separated by ``_``

     ``VERSION``
       The library's build version will be set to
       :cmake:variable:`CETMODULES_CURRENT_PROJECT_NAME` (*cf* :cmake:prop_tgt:`VERSION`).

   **Deprecated options:**

     ``SOURCE <source>...``
       Specify sources to compile into the plugin.

      .. deprecated:: 2.11
         use ``IMPL_SOURCE``, ``REG_SOURCE`` and ``LIBRARIES REG``
         instead.

     ``USE_PRODUCT_NAME``

       .. deprecated:: 2.0
          use ``USE_PACKAGE_NAME`` instead.

   **Non-option arguments:**

     ``<name>``

     The name stem for the library to be generated.

     ``<suffix>``

     The category of plugin to be generated.

   .. seealso:: :cmake:command:`cet_make_library`
#]================================================================]
function(basic_plugin NAME SUFFIX)
  cmake_parse_arguments(PARSE_ARGV 2 BP
    "${cet_bp_flags}" "${cet_bp_one_arg_opts}" "${cet_bp_list_options}")
  if (BP_UNPARSED_ARGUMENTS)
    warn_deprecated("use of non-option arguments (${BP_UNPARSED_ARGUMENTS})"
      NEW "LIBRARIES")
    list(APPEND BP_LIBRARIES NOP ${BP_UNPARSED_ARGUMENTS})
  endif()
  if (BP_BASENAME_ONLY AND BP_USE_PRODUCT_NAME)
    message(FATAL_ERROR "BASENAME_ONLY AND USE_PRODUCT_NAME are mutually exclusive")
  endif()
  if (BP_BASENAME_ONLY)
    set(plugin_stem "${NAME}")
  else()
    cet_package_path(CURRENT_SUBDIR)
    if (NOT BP_ALLOW_UNDERSCORES)
      if (CURRENT_SUBDIR MATCHES _)
        message(FATAL_ERROR  "found underscore in plugin subdirectory: ${CURRENT_SUBDIR}" )
      endif()
      if (NAME MATCHES _)
        message(FATAL_ERROR  "found underscore in plugin name: ${NAME}" )
      endif()
    endif()
    string(REPLACE "/" "_" plugin_stem "${CURRENT_SUBDIR}")
    if (BP_USE_PRODUCT_NAME)
      string(JOIN "_" plugin_stem "${CETMODULES_CURRENT_PROJECT_NAME}" "${plugin_stem}")
    endif()
    string(JOIN "_" plugin_stem  "${plugin_stem}" "${NAME}")
  endif()
  if (BP_SOURCE)
    warn_deprecated("SOURCE" NEW "IMPL_SOURCE, REG_SOURCE and LIBRARIES REG")
    if (BP_REG_SOURCE)
      message(FATAL_ERROR "SOURCE and REG_SOURCE are mutually exclusive")
    endif()
    set(BP_REG_SOURCE "${BP_SOURCE}")
  elseif (NOT BP_REG_SOURCE)
    set(BP_REG_SOURCE "${NAME}_${SUFFIX}.cc")
  endif()
  set(cml_args)
  ##################
  # These items are common to implementation and plugin libraries.
  foreach (kw IN ITEMS EXPORT_SET LOCAL_INCLUDE_DIRS SOVERSION)
    cet_passthrough(APPEND BP_${kw} cml_common_args)
  endforeach()
  foreach (kw IN ITEMS BASENAME_ONLY NO_INSTALL
      USE_PRODUCT_NAME VERSION)
    cet_passthrough(FLAG APPEND BP_${kw} cml_common_args)
  endforeach()
  # These items are only for the implementation library.
  foreach (kw IN ITEMS ALIAS)
    cet_passthrough(APPEND BP_${kw} cml_impl_args)
  endforeach()
  foreach (kw IN ITEMS NO_EXPORT USE_BOOST_UNIT)
    cet_passthrough(FLAG APPEND BP_${kw} cml_impl_args)
  endforeach()
  ##################
  set(target_thunk)
  cmake_parse_arguments(BPL "NOP" ""
    "CONDITIONAL;INTERFACE;PRIVATE;PUBLIC;REG" ${BP_LIBRARIES})
  list(APPEND BPL_PUBLIC ${BPL_UNPARSED_ARGUMENTS})
  if (NOT BP_IMPL_SOURCE) # See if we can find one.
    get_filename_component(if_plugin_impl "${NAME}.cc" REALPATH)
    if (EXISTS "${if_plugin_impl}")
      set(BP_IMPL_SOURCE "${NAME}.cc")
    endif()
  endif()
  if (BP_IMPL_SOURCE OR
      NOT (BPL_INTERFACE OR BPL_PUBLIC OR
        BPL_KEYWORDS_MISSING_VALUES MATCHES "(^|;)(INTERFACE|PUBLIC)(;|$)"))
    set(REG_LIB_TYPE MODULE)
    if (BP_IMPL_SOURCE)
      list(APPEND BPL_PUBLIC ${BPL_CONDITIONAL})
      list(REMOVE_DUPLICATES BPL_PUBLIC)
      cet_make_library(LIBRARY_NAME "${plugin_stem}_${SUFFIX}"
        SOURCE ${BP_IMPL_SOURCE}
        LIBRARIES
        INTERFACE ${BPL_INTERFACE}
        PUBLIC ${BPL_PUBLIC}
        PRIVATE ${BPL_PRIVATE}
        NOP ${cml_common_args} ${cml_impl_args})
      # For backward compatibility purposes, we retain the vanilla
      # target name but have a different name for the implementation
      # library on disk.
      set_target_properties("${plugin_stem}_${SUFFIX}"
        PROPERTIES OUTPUT_NAME "${plugin_stem}"
      )
      # Thunk the target name of the plugin library so we don't attempt
      # to link to it, but retain the vanilla library name for backward
      # compatibility.
      set(target_thunk _plugin)
      # Trim the library list for the registration library:
      set(BP_LIBRARIES PRIVATE "${plugin_stem}_${SUFFIX}" ${BPL_REG})
      unset(cml_impl_args)
    else() # One combined module that we've been told is safe:
      set(BP_LIBRARIES PRIVATE ${BPL_CONDITIONAL} ${BPL_PRIVATE} ${BPL_REG})
    endif()
  else()
    set(REG_LIB_TYPE SHARED)
    list(APPEND BPL_PUBLIC ${BPL_CONDITIONAL})
    list(REMOVE_DUPLICATES BPL_PUBLIC)
    list(APPEND BPL_PRIVATE ${BPL_REG})
    list(REMOVE_DUPLICATES BPL_PRIVATE)
    set(BP_LIBRARIES INTERFACE ${BPL_INTERFACE}
      PUBLIC ${BPL_PUBLIC} PRIVATE ${BPL_PRIVATE})
    if (CET_WARN_DEPRECATED)
      message(AUTHOR_WARNING "prefer separate compilation units for implementation (IMPL_SOURCE) and plugin registration macros (REG_SOURCE, LIBRARIES REG) due to possible consequences of One Definition Rule violation")
    endif()
  endif()
  ##################
  # These items are applicable only to the implementation library.
  cet_passthrough(IN_PLACE BP_REG_SOURCE
    KEYWORD SOURCE EMPTY_KEYWORD NO_SOURCE)
  ##################
  # Make the plugin library, to which we should not normally link
  # directly (see REG_SOURCE, above).
  #
  # Module-type libraries containing only plugin registration code can
  # be stripped.
  cet_passthrough(FLAG APPEND target_thunk KEYWORD STRIP_LIBS cml_impl_args)
  if (REG_LIB_TYPE STREQUAL "MODULE" AND NOT NO_INSTALL)
    # We don't want the plugin-only library visible as an exported target.
    list(APPEND cml_impl_args NO_EXPORT)
  endif()
  cet_make_library(LIBRARY_NAME "${plugin_stem}_${SUFFIX}${target_thunk}"
    ${REG_LIB_TYPE}
    ${BP_REG_SOURCE}
    ${cml_common_args} ${cml_impl_args}
    LIBRARIES ${BP_LIBRARIES}
  )
  if (target_thunk)
    set_target_properties(${plugin_stem}_${SUFFIX}${target_thunk}
      PROPERTIES OUTPUT_NAME "${plugin_stem}_${SUFFIX}"
    )
  endif()
endfunction()

cmake_policy(POP)
